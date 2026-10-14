# PT XYZ Data Warehouse - orkestrasi satu perintah:  make all
SHELL   := /bin/bash
DB      ?= PTXYZ_DataWarehouse
NETWORK ?= ptxyz-dw_dw_network
UID_GID := $(shell id -u):$(shell id -g)

# sqlcmd di dalam container sqlserver; password dibaca dari env container (berasal dari .env)
SQLCMD = docker compose exec -T sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -C -N -b -W -d $(DB) $(1)'

.PHONY: help setup build up wait etl validate all down restart logs logs-sql logs-airflow status shell-sql backup clean

help:
	@echo "PT XYZ Data Warehouse"
	@echo "  make all        - dari nol: setup, up, wait, etl, validate"
	@echo "  make setup      - patch orkestrasi + buat .env (idempotent)"
	@echo "  make up         - jalankan semua layanan (docker compose up -d)"
	@echo "  make wait       - tunggu database & skema siap"
	@echo "  make etl        - jalankan standalone_etl.py di container Python"
	@echo "  make validate   - jalankan tests/validate.sql (skema, FK, agregat)"
	@echo "  make down       - hentikan layanan (data tetap)"
	@echo "  make clean      - hentikan + HAPUS volume data proyek ini (tanpa docker system prune)"
	@echo "  make status | logs | logs-sql | logs-airflow | shell-sql | backup"

setup:
	@python3 scripts/apply_patches.py

build: setup
	docker compose build

up: setup
	docker compose up -d
	@echo "Layanan: SQL Server :1433 | Airflow :8080 | Grafana :3000 | Superset :8088 | Metabase :3001 | Jupyter :8888"

wait:
	@bash scripts/wait_for_init.sh 900

etl:
	docker run --rm --network $(NETWORK) -v "$(CURDIR)":/work -w /work -e MSSQL_HOST=sqlserver python:3.12-slim \
	  sh -c "pip install -q --no-cache-dir pandas pymssql && python standalone_etl.py; rc=\$$?; chown $(UID_GID) etl_execution.log 2>/dev/null; exit \$$rc"

validate:
	$(call SQLCMD,-i /tests/validate.sql)

all: up wait etl validate olap

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

logs-sql:
	docker compose logs -f sqlserver

logs-airflow:
	docker compose logs -f airflow-webserver airflow-scheduler airflow-worker

status:
	docker compose ps

shell-sql:
	docker compose exec sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -C -N -d $(DB)'

backup:
	mkdir -p backups
	docker run --rm -v ptxyz-dw_sqlserver_data:/data -v "$(CURDIR)/backups":/backup alpine \
	  sh -c "tar czf /backup/sqlserver_backup_$$(date +%Y%m%d_%H%M%S).tar.gz /data"

# Hanya menghapus container + volume milik proyek ini. Sengaja TIDAK memakai 'docker system prune'.
clean:
	docker compose down -v --remove-orphans

.PHONY: olap
olap:
	docker compose exec -T sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$$MSSQL_SA_PASSWORD" -C -N -b -W -d PTXYZ_DataWarehouse -i /tests/olap.sql' > tests/olap_output.txt 2>&1; rc=$$?; cat tests/olap_output.txt; exit $$rc
