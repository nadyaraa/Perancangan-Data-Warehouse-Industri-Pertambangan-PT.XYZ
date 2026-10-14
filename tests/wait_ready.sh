#!/usr/bin/env bash
# Tunggu SQL Server + database + 14 tabel hasil db_init siap (maks ~7,5 menit).
set -u
SVC="${SQLSERVER_SVC:-sqlserver}"
DB="${MSSQL_DB:-PTXYZ_DataWarehouse}"
n=0
for i in $(seq 1 90); do
  n=$(docker compose exec -T "$SVC" sh -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -N -W -h -1 -d $DB -Q \"SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA IN ('dim','fact','staging')\"" 2>/dev/null | tr -d '[:space:]')
  case "$n" in ''|*[!0-9]*) n=0;; esac
  if [ "$n" -ge 14 ]; then echo "siap: database $DB ada, $n tabel terbentuk"; exit 0; fi
  sleep 5
done
echo "timeout: database/tabel belum siap (tabel terdeteksi: $n)"; exit 1
