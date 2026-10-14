#!/usr/bin/env python3
"""Patch ORKESTRASI untuk repo PT XYZ DW. Idempotent (aman dijalankan berulang).

Tidak mengubah skema inti maupun logika SQL/ETL. Hanya:
  1. docker-compose.yml : healthcheck sqlserver membaca password dari env (bukan hardcode),
                          password default diganti error eksplisit, mount ./tests -> /tests
  2. standalone_etl.py  : kredensial/host/port/db dari .env / env (bukan hardcode)
  3. airflow/plugins/   : folder yang diminta airflow/Dockerfile tetapi tidak ada di repo
  4. data/raw/Dataset/  : lokasi CSV yang dibaca standalone_etl.py
  5. .env               : dibuat dari .env.example dengan password acak bila belum ada
"""
import pathlib, secrets, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
changed = []


def edit(path, fn, label):
    p = ROOT / path
    s = p.read_text(encoding="utf-8")
    new = fn(s)
    if new != s:
        p.write_text(new, encoding="utf-8")
        changed.append(label)


def patch_compose(s):
    old = "-P 'PTXYZSecure123!' -Q 'SELECT 1'"
    new = '-P \\"$$MSSQL_SA_PASSWORD\\" -Q \'SELECT 1\''
    s = s.replace(old, new)
    # fallback password default diganti error eksplisit bila .env belum diisi
    s = s.replace(":-PTXYZSecure123!}", ":?MSSQL_SA_PASSWORD belum diisi di .env}")
    mount = "      - ./init-scripts:/init-scripts\n"
    if "./tests:/tests" not in s and mount in s:
        s = s.replace(mount, mount + "      - ./tests:/tests:ro\n", 1)
    return s


LOADER = '''import os

def _load_dotenv(path='.env'):
    """Baca .env (KEY=VALUE) ke os.environ tanpa menimpa variabel yang sudah ada."""
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

_load_dotenv()
'''


def patch_etl(s):
    if "_load_dotenv" not in s:
        s = s.replace("import os\n", LOADER, 1)
    s = s.replace("password='PTXYZSecure123!',", "password=os.environ['MSSQL_SA_PASSWORD'],")
    s = s.replace("server='localhost',", "server=os.environ.get('MSSQL_HOST', 'localhost'),")
    s = s.replace("port=1433,", "port=int(os.environ.get('MSSQL_PORT', '1433')),")
    s = s.replace("database='PTXYZ_DataWarehouse',", "database=os.environ.get('MSSQL_DB', 'PTXYZ_DataWarehouse'),")
    return s


edit("docker-compose.yml", patch_compose, "docker-compose.yml (healthcheck + mount /tests)")
edit("standalone_etl.py", patch_etl, "standalone_etl.py (kredensial dari .env)")

plugins = ROOT / "airflow" / "plugins"
if not plugins.exists():
    plugins.mkdir(parents=True)
    (plugins / ".gitkeep").touch()
    changed.append("airflow/plugins/.gitkeep")

dest = ROOT / "data" / "raw" / "Dataset"
dest.mkdir(parents=True, exist_ok=True)
for csv in sorted((ROOT / "data").glob("*.csv")):
    t = dest / csv.name
    if not t.exists() or t.read_bytes() != csv.read_bytes():
        shutil.copy2(csv, t)
        changed.append(f"data/raw/Dataset/{csv.name}")

env, example = ROOT / ".env", ROOT / ".env.example"
if not env.exists() and example.exists():
    lines = []
    for ln in example.read_text(encoding="utf-8").splitlines():
        if ln.startswith("MSSQL_SA_PASSWORD="):
            ln = "MSSQL_SA_PASSWORD=Px" + secrets.token_hex(8) + "Q9"  # huruf besar+kecil+angka, aman untuk shell
        lines.append(ln)
    env.write_text("\n".join(lines) + "\n", encoding="utf-8")
    changed.append(".env (dibuat, MSSQL_SA_PASSWORD acak)")

print("Patch diterapkan:" if changed else "Semua patch sudah terpasang (tidak ada perubahan).")
for c in changed:
    print("  -", c)
