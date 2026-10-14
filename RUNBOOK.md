# RUNBOOK — Replikasi Data Warehouse Pertambangan PT XYZ

| | |
|---|---|
| **Repo (fork)** | https://github.com/nadyaraa/Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ |
| **Sumber README** | https://github.com/sains-data/Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ |
| **Nama / NIM** | Nadya Ramadhani / 2410817120019 |
| **Tanggal eksekusi** | 14 Oktober 2026 |
| **Lingkungan** | WSL2 (Ubuntu), Docker Compose V2, SQL Server 2022 (kontainer), Python 3 + venv |

Dokumen ini menjelaskan cara menjalankan, memvalidasi, dan memahami hasil replikasi Data Warehouse PT XYZ sesuai README repo. Skema inti (nama tabel/kolom/tipe) dan logika ETL **tidak diubah**. Perubahan hanya pada orkestrasi: pengelolaan kredensial lewat `.env`, penunggu kesiapan layanan, dan tes validasi otomatis.

---

## 1. Ringkasan hasil

| Klaim README | Hasil replikasi | Status |
|---|---|---|
| 8 tabel dimensi dan 3 tabel fakta (star schema) | 11 tabel ada di skema `dim` dan `fact`, plus 3 tabel `staging` | Sesuai |
| Jumlah baris seluruh tabel (DimTime 830, DimSite 1.747, …, FactEquipmentUsage 236.892, FactProduction 2.261, FactFinancialTransaction 115.901) | Semua 11 tabel sama persis | Sesuai |
| Produksi Metal 434.721 dan Ore 112.687 | 434.721,00 dan 112.687,00 (filter `date >= '2025-05-01'`) | Sesuai |
| 100% referential integrity | 12 FK fact→dim terdeteksi, 0 orphan | Sesuai |
| KPI efisiensi peralatan 95,66% | 95,6029% | **Selisih terdokumentasi** (lihat bagian 8) |

Hasil validasi otomatis: `PASS=62  WARN=7  FAIL=0`. Hasil ini sama pada build pertama, build bersih dari nol (`docker compose down -v`), dan pada eksekusi ulang tanpa menghapus volume.

---

## 2. Arsitektur

```
                  data/raw/Dataset/*.csv  (3 file sumber, dipakai apa adanya)
                              |
                              v
   +-----------------------------------------------------------+
   |  standalone_etl.py  (Python, pandas + pymssql)            |
   |  1. staging  ->  2. dimensi  ->  3. fakta  ->  4. cek DQ |
   +-----------------------------------------------------------+
                              |
                              v
   +-----------------------------------------------------------+
   |  SQL Server 2022 (kontainer ptxyz_sqlserver, port 1433)   |
   |  DB: PTXYZ_DataWarehouse                                  |
   |  skema: staging | dim (8 tabel) | fact (3 tabel)          |
   +-----------------------------------------------------------+
        ^                 ^                  ^
        |                 |                  |
  tests/validate.sql   Airflow (8080)   Grafana (3000) / Superset (8088)
  (validasi otomatis)  + Postgres,      Metabase (3001) / Jupyter (8888)
                       Redis            (lapisan visualisasi README)
```

| Layanan | Fungsi | Port |
|---|---|---|
| `sqlserver` | Data warehouse utama | 1433 |
| `db_init` | Satu kali jalan: membuat database, skema, dan tabel dari `init-scripts/` | — |
| `postgres`, `redis` | Metadata dan broker Airflow | 5432, 6379 |
| `airflow-*` | Orkestrasi ETL (webserver, scheduler, worker) | 8080 |
| `grafana`, `superset`, `metabase`, `jupyter` | Visualisasi dan analisis | 3000, 8088, 3001, 8888 |

Catatan: validasi otomatis hanya menguji lapisan data (SQL Server dan ETL). Status lapisan visualisasi dan Airflow tidak termasuk tes otomatis.

---

## 3. Cara menjalankan (satu perintah)

Prasyarat: Docker Engine 20.10+, Docker Compose V2, minimal 8 GB RAM, Python 3 dengan `pymssql` dan `pandas` (`pip install -r requirements.txt`).

```bash
git clone https://github.com/nadyaraa/Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ.git
cd Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ
cp .env.example .env                  # lalu isi MSSQL_SA_PASSWORD dengan password kuat
make -f Makefile.validasi all         # up -> wait -> etl -> test-schema -> validate -> olap
```

Kredensial tidak ditulis di kode. Semua nilai dibaca dari `.env` (tidak masuk git; `.env.example` hanya berisi placeholder). Password SQL Server harus memenuhi aturan kompleksitas (huruf besar, huruf kecil, angka, minimal 8 karakter).

Target Makefile:

| Target | Fungsi |
|---|---|
| `up` | `docker compose up -d` |
| `wait` | Menunggu sampai database `PTXYZ_DataWarehouse` dan 14 tabel hasil `db_init` benar-benar ada (`tests/wait_ready.sh`) |
| `etl` | Menjalankan `python standalone_etl.py`; gagal jika log memuat `ETL Pipeline failed` atau `Traceback` |
| `schema-baseline` | Menyimpan skema (nama/tipe kolom) ke `tests/expected_schema.txt` |
| `test-schema` | Membandingkan skema aktual dengan baseline (`diff`) |
| `validate` | Menjalankan `tests/validate.sql` |
| `olap` | Menjalankan `tests/olap.sql` (slice, dice, roll-up, drill-down, pivot); keluaran disimpan ke `tests/olap_output.txt` |
| `down` | `docker compose down` |

### Dua pintu masuk Makefile

Repo memiliki dua Makefile. Keduanya memakai skrip SQL yang sama (`tests/validate.sql` dan `tests/olap.sql`).

| | `make all` (file `Makefile`) | `make -f Makefile.validasi all` |
|---|---|---|
| ETL | Dijalankan di kontainer `python:3.12-slim` pada jaringan Compose, sehingga yang dibutuhkan hanya Docker | `python standalone_etl.py` di host (butuh Python, pandas, dan pymssql) |
| Tes skema terpisah (`test-schema`) | Tidak ada; perbandingan skema dilakukan di dalam `validate.sql` (kategori "Skema Kolom & tipe") | Ada (diff terhadap `tests/expected_schema.txt`) |
| Urutan | up, wait, etl, validate, olap | up, wait, etl, test-schema, validate, olap |

Jalur yang disarankan untuk penilai adalah `make all`, karena tidak membutuhkan instalasi Python di host.

---

## 4. Pemetaan langkah README → perintah

| # | Langkah di README | Perintah yang dijalankan | Catatan |
|---|---|---|---|
| 1 | Siapkan environment (`ls -la .env`) | `cp .env.example .env` dan isi password | Password tidak lagi hard-code di repo |
| 2 | Bersihkan Docker (`docker system prune -af --volumes`) | `docker compose down -v` | Padanan yang lebih aman: hanya menghapus kontainer dan volume proyek ini, tidak seluruh Docker di mesin. Hasil akhir sama (database dibangun dari nol) |
| 3 | Jalankan semua layanan (`docker compose up -d`) | `make -f Makefile.validasi up` | Sama |
| 3b | "Tunggu 5-10 menit sampai siap" (langkah manual) | `make -f Makefile.validasi wait` | Langkah manual di-script: polling sampai database dan tabel ada |
| 4 | Akses layanan (Airflow, Grafana, dll.) | Buka URL pada tabel bagian 2 | Di luar tes otomatis |
| 5 | Jalankan ETL (`python standalone_etl.py`) | `make -f Makefile.validasi etl` | Tanpa perubahan logika |
| 6 | Pengujian (`./test.sh`, `check_schema.py`, dll. di README) | `make -f Makefile.validasi test-schema validate` | Padanan: tes skema, FK, agregat, dan DQ berbasis SQL (bagian 6) |
| 7 | Analitik OLAP (tambahan sesuai lingkup tugas, README hanya menyebut analitik dan dashboard secara umum) | `make -f Makefile.validasi olap` | Hanya `SELECT`; bukti di Lampiran A |

Seluruh urutan di atas dijalankan sekaligus oleh `make -f Makefile.validasi all` (urutan: up, wait, etl, test-schema, validate, olap).

---

## 5. Sumber data dan alur ETL

**Sumber data.** README tidak membutuhkan data sintetis: repo menyediakan tiga file CSV contoh di `data/raw/Dataset/`, yang dipakai **apa adanya** tanpa modifikasi:

| File | Ukuran | Dimuat ke |
|---|---|---|
| `dataset_alat_berat_dw.csv` | ± 202 KB | `staging.EquipmentUsage` (1.150 baris) |
| `dataset_production.csv` | ± 238 KB | `staging.Production` (1.150 baris) |
| `dataset_transaksi.csv` | ± 214 KB | `staging.FinancialTransaction` (1.150 baris) |

Tidak ada skrip pembangkit data sintetis pada replikasi ini.

**Alur `standalone_etl.py`:**

1. **Staging**: kosongkan tabel staging, muat tiga CSV (batch 100 baris).
2. **Dimensi**: `DimTime` (830), `DimSite` (1.747), `DimEquipment` (6), `DimMaterial` (5), `DimEmployee` (10), `DimShift` (3), `DimProject` (50), `DimAccount` (30).
3. **Fakta**: `FactEquipmentUsage` (236.892), `FactProduction` (2.261), `FactFinancialTransaction` (115.901) — total 355.054 baris. Jumlah baris fakta lebih besar daripada staging karena langkah transformasi menggabungkan data staging dengan dimensi.
4. **Cek kualitas data** bawaan ETL (menghitung baris tiap tabel).

**Performa terukur.** Eksekusi ETL lengkap memakan ± 17 detik (13:24:50–13:25:07) pada run pertama dan ± 13 detik pada run ulang, jauh di bawah target README (< 5 menit untuk 350 ribu+ baris).

**Deterministik dan idempoten.** Tiga eksekusi (build pertama, build bersih setelah `down -v`, dan eksekusi ulang tanpa menghapus volume) menghasilkan jumlah baris dan agregat yang identik. ETL aman dijalankan berulang.

---

## 6. Validasi otomatis

Jalankan satu perintah:

```bash
make -f Makefile.validasi validate
# setara dengan:
docker compose exec -T sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -N -b -W -d PTXYZ_DataWarehouse' < tests/validate.sql
```

Skrip `tests/validate.sql` menghasilkan tabel `PASS | WARN | FAIL` dan berakhir dengan kode keluar tidak nol jika ada `FAIL` (opsi `-b`). Isinya:

| Kategori (kolom `kategori`) | Yang diuji | Jumlah |
|---|---|---|
| Skema: Tabel ada | 11 tabel `dim` dan `fact` serta 3 tabel `staging` ada | 14 |
| Skema: Kolom & tipe | Nama, tipe, panjang, presisi, dan nullability seluruh kolom (107 baris) dibandingkan dengan `tests/expected_schema.txt`; hasil `0 kolom tidak sesuai` per tabel | 11 |
| Jumlah baris README | Jumlah baris 11 tabel = angka README | 11 |
| Integritas | Jumlah FK fact-ke-dim terdeteksi = 12, ditambah 12 tes orphan = 0 | 13 |
| Agregat README | Metal, Ore, baris peralatan (date >= 2025-05-01), efisiensi keseluruhan | 4 |
| Rentang nilai | Jam, downtime, BBM, biaya >= 0; efficiency_ratio di [0,1]; volume, unit_cost, quantity >= 0; budget, actual, cost >= 0 | 4 |
| Duplikasi | Kunci unik pada 6 dimensi (equipment_name, material_id, employee_id, shift_id, project_id, account_id) | 6 |
| Temuan DQ (informatif) | Rasio baris terhadap kunci unik pada DimSite, DimTime, dan tiga fakta; `variance_status` NULL seluruhnya | 6 |
| Total | | 69 |

Tujuh `WARN` terdiri dari efisiensi 95,66% vs 95,60% (no. 53) dan enam temuan DQ (no. 64-69). Tidak ada `FAIL`.

Baseline skema (`tests/expected_schema.txt`) diambil dari database hasil `init-scripts/` repo yang belum diubah, sehingga mewakili definisi skema normatif README.

---

## 7. Bukti hasil

Cuplikan verbatim dari keluaran tahap `validate` pada `make clean && make all` (14 Okt 2026). Log lengkap: `tests/make_all.log`, `tests/last_run.log`, dan `tests/rerun.log`.

```
seq kategori uji status detail
--- -------- --- ------ ------
1 Skema Tabel ada: dim.DimTime PASS
15 Skema Kolom & tipe: dim.DimAccount PASS 0 kolom tidak sesuai
26 Jumlah baris README: dim.DimTime = 830 PASS aktual = 830
34 Jumlah baris README: fact.FactEquipmentUsage = 236892 PASS aktual = 236892
35 Jumlah baris README: fact.FactProduction = 2261 PASS aktual = 2261
36 Jumlah baris README: fact.FactFinancialTransaction = 115901 PASS aktual = 115901
37 Integritas Jumlah FK constraint pada tabel fakta = 12 PASS aktual = 12
38 Integritas Orphan = 0: fact.FactEquipmentUsage.time_key -> dim.DimTime.time_key PASS orphan = 0
49 Integritas Orphan = 0: fact.FactFinancialTransaction.account_key -> dim.DimAccount.account_key PASS orphan = 0
50 Agregat README: Produksi Metal = 434.721 (date >= anchor) PASS aktual = 434721.00
51 Agregat README: Produksi Ore = 112.687 (date >= anchor) PASS aktual = 112687.00
52 Agregat README: baris peralatan 30 hari = 118.446 (date >= anchor) PASS aktual = 118446
53 Agregat README: efisiensi keseluruhan = 95,66% WARN aktual = 95.60; selisih = 0.06 poin (tidak ada rumus di repo yang menghasilkan 95,66)
64 Temuan DQ DimSite: baris vs site_name unik WARN baris = 1747; kunci unik = 26; faktor = 67.2x
65 Temuan DQ DimTime: baris vs time_id unik WARN baris = 830; kunci unik = 755; faktor = 1.1x
66 Temuan DQ FactEquipmentUsage: baris vs equipment_usage_id unik WARN baris = 236892; kunci unik = 1150; faktor = 206.0x
67 Temuan DQ FactProduction: baris vs production_id unik WARN baris = 2261; kunci unik = 1150; faktor = 2.0x
68 Temuan DQ FactFinancialTransaction: baris vs transaction_id unik WARN baris = 115901; kunci unik = 1150; faktor = 100.8x
69 Temuan DQ FactFinancialTransaction.variance_status terisi (ETL tidak memuat kolom ini) WARN NULL = 115901 dari 115901 baris

RINGKASAN: PASS=62  WARN=7  FAIL=0
```

Baris yang tidak ditampilkan (no. 2-14, 16-25, 27-33, 39-48, 54-63) seluruhnya `PASS`; daftar lengkap ada di log. Bukti OLAP ada di Lampiran A.

---

## 8. Selisih terdokumentasi dan padanan

| # | Hal | README | Replikasi | Penjelasan |
|---|---|---|---|---|
| 1 | Efisiensi peralatan | 95,66% | 95,6029% (rata-rata `efficiency_ratio`); 95,5950% (rasio jam operasi / total jam) | Seluruh varian hitung yang dicoba (semua data, sejak 2025-05-01, per baris, per tahun) menghasilkan 95,60%. README tidak menyertakan query untuk angka ini. Selisih 0,06 poin dicatat sebagai `WARN` (toleransi 0,10), logika tidak diubah |
| 2 | Filter tanggal agregat | README tidak menyebut tanggal | Batas tetap `date >= '2025-05-01'` | Angka Metal 434.721 dan Ore 112.687 persis cocok pada batas ini (selisih 0). Ini **kesimpulan dari data**, bukan fakta tertulis: kemungkinan README dihasilkan dari query dengan jendela 30 hari terakhir yang dijalankan sekitar akhir Mei 2025. Batas tetap dipakai agar tes deterministik di tanggal mana pun (menggantikan `DATEADD(day,-30,GETDATE())`) |
| 3 | Data 2022 dan 2025 | — | Tahun 2022 dan 2025 masing-masing 118.446 baris peralatan dengan rata-rata efisiensi identik | Dugaan: blok 2025 adalah salinan blok 2022 dari proses pembangkit data. Ini menjelaskan mengapa dua tanggal awal (`2022-04-11` dan `2025-05-01`) menghasilkan agregat sama |
| 4 | Nama database | Bagian "Service Details" README menulis `PTXYZ_DW` | `PTXYZ_DataWarehouse` | Init-scripts, ETL, dan docker-compose repo konsisten memakai `PTXYZ_DataWarehouse`; nama di README adalah ketidakkonsistenan dokumentasi. Nama yang dipakai kode tidak diubah |
| 5 | Pembersihan Docker | `docker system prune -af --volumes` | `docker compose down -v` | Lihat bagian 4, baris 2 |
| 6 | Langkah manual "tunggu 5–10 menit" | Manual | `tests/wait_ready.sh` | Di-script sesuai aturan tugas |
| `scripts/apply_patches.py` | Dipanggil target `setup` pada `make all`. Patch orkestrasi yang idempotent: kredensial dari `.env`, mount `./tests` di compose, pembuatan `.env` dengan password acak bila belum ada. Tidak mengubah skema atau logika SQL/ETL |
| `scripts/wait_for_init.sh` | Penunggu kesiapan untuk `make all` (batas waktu 900 detik); padanan `tests/wait_ready.sh` pada `Makefile.validasi` |

---

## 9. Kendala dan solusi

| # | Kendala | Gejala | Penyebab | Solusi |
|---|---|---|---|---|
| 1 | Kredensial tertanam di banyak file | `grep` menemukan password di `docker-compose.yml`, `standalone_etl.py`, 4 file DAG, skrip dashboard, `quick-start.sh`, dokumen dashboard | Password ditulis langsung di kode | 14 file dibersihkan: kode memakai `MSSQL_SA_PASSWORD` dari `.env`, dokumentasi memakai placeholder, default di compose diganti `${MSSQL_SA_PASSWORD:?...}` agar compose berhenti jika variabel kosong. `quick-start.sh` kini membuat password acak jika `.env` belum ada |
| 2 | Default password di compose tidak konsisten | Dua default berbeda (`...12!` dan `...123!`) | Salah ketik di repo asli | Terselesaikan dengan menghapus default (poin 1) |
| 3 | ETL gagal dengan `Login failed for user 'sa'` (error 18456) tepat setelah `make wait` | Pesan menyesatkan: terlihat seperti password salah | ETL menyambung dengan `database='PTXYZ_DataWarehouse'` sebelum `db_init` selesai membuat database. SQL Server melaporkan database yang belum ada sebagai kegagalan login. `make wait` lama hanya menunggu `SELECT 1` | `tests/wait_ready.sh` menunggu sampai database dan 14 tabel (dim, fact, staging) ada. Diagnosis: login dari host ke `localhost` dan `127.0.0.1` terbukti berhasil, panjang password sama di `.env`, `make`, dan kontainer |
| 4 | ETL gagal tapi `make` tetap lanjut | `standalone_etl.py` mencatat `ETL Pipeline failed` namun keluar dengan kode 0 | Script menangkap exception tanpa `sys.exit(1)` | Target `etl` mengalirkan log ke `tests/etl.log` dan gagal jika memuat `ETL Pipeline failed` atau `Traceback`. Logika ETL tidak diubah |
| 5 | Tes tanggal bergantung hari eksekusi | Agregat README cocok hanya pada jendela tanggal tertentu | README memakai filter relatif terhadap tanggal run | Batas tetap 2025-05-01 (bagian 8, poin 2) |
| 6 | Kekhawatiran idempotensi | ETL dijalankan dua kali tanpa `down -v` | — | Diuji: jumlah baris dan agregat tetap identik |
| 7 | Pesan `git commit`/`push` gagal | `Author identity unknown`; `Password authentication is not supported` | Identitas git belum diatur; GitHub menolak password akun | `git config user.name/user.email` dan Personal Access Token (atau `gh auth login`) |
| 8 | File kosong `LOGIN` muncul di root repo | Muncul di `git status` | Salah redirect di terminal | Dihapus sebelum commit |

---

## 10. Pengelolaan kredensial

- `.env` ada di `.gitignore`; yang di-commit hanya `.env.example` (placeholder).
- Kunci utama: `MSSQL_SA_PASSWORD` (dibaca docker-compose, `standalone_etl.py`, DAG Airflow, dan skrip dashboard).
- Password SQL Server memakai format `Pw<hex>aA1` (alfanumerik) agar aman dari interpretasi karakter khusus oleh shell, `make`, dan Compose.
- Password lama masih ada di riwayat git repo asli; password aktif sudah berbeda dan tidak pernah di-commit.

---

## 11. Daftar file tambahan (hanya orkestrasi dan tes)

| File | Fungsi |
|---|---|
| `Makefile.validasi` | Orkestrasi satu perintah (`all`) |
| `tests/validate.sql` | Validasi otomatis (skema, baris, orphan FK, agregat, DQ) |
| `tests/olap.sql` | Kueri OLAP (slice, dice, roll-up, drill-down, pivot, drill-across, coverage, self-test); hanya `SELECT` |
| `tests/olap_output.txt` | Keluaran terakhir `make olap` (bukti Lampiran A) |
| `tests/make_all.log` | Log lengkap build bersih (`make clean` lalu `make all`) |
| `tests/wait_ready.sh` | Penunggu kesiapan database dan tabel |
| `tests/expected_schema.txt` | Baseline skema untuk `test-schema` |
| `tests/anchor.sql`, `anchor2.sql`, `anchor3.sql`, `explore.sql` | Skrip eksplorasi yang menurunkan batas tanggal dan memeriksa jumlah baris/efisiensi |
| `tests/last_run.log`, `tests/rerun.log` | Bukti eksekusi build bersih dan eksekusi ulang |
| `RUNBOOK.md` | Dokumen ini |

---

## 12. Lapisan cloud (LocalStack: S3, Lambda, EventBridge, Glue, RDS)

Lapisan cloud (LocalStack: S3, Lambda, EventBridge, Glue, RDS) **belum diimplementasikan** pada pengumpulan ini dan tidak termasuk kriteria penilaian tugas. Padanan RDS for SQL Server yang dipakai adalah kontainer SQL Server 2022 pada Docker Compose. Seluruh pipeline berjalan tanpa layanan cloud.

---

## 13. Pemetaan ke rubrik penilaian

| Kriteria | Bukti |
|---|---|
| Kepatuhan ke README (35%) | Bagian 1, 4, 8: seluruh jumlah baris dan agregat cocok; selisih efisiensi didokumentasikan |
| Reproducibility dan orkestrasi (25%) | Bagian 3: Docker Compose + `make all`, `.env`, build bersih dan run ulang terbukti |
| Validasi otomatis (15%) | Bagian 6 dan 7: skema, FK/orphan, agregat, DQ; satu perintah |
| Lingkup OLAP (slice, dice, roll-up, drill-down, pivot) | Lampiran A: `make olap`, `tests/olap.sql`, `tests/olap_output.txt`; produksi Metal dan Ore cocok dengan README |
| Kualitas ETL dan DQ (15%) | Bagian 5, 6, 9: log ETL, penanganan kegagalan, cek rentang dan duplikasi |
| Dokumentasi (10%) | Dokumen ini |

---

## Lampiran A. Kueri OLAP (`tests/olap.sql`)

Dijalankan dengan `make olap` (juga otomatis oleh `make all`). Keluaran lengkap tersimpan di `tests/olap_output.txt`. File ini hanya berisi `SELECT`, tidak mengubah skema. Parameter slice/dice dipilih otomatis dari data (nilai produksi tertinggi), sehingga tidak ada nilai yang di-hardcode: pada eksekusi ini tahun = 2027, region = Sumatera, material_type = Metal.

| No | Operasi OLAP | Isi kueri |
|---|---|---|
| 1 | Slice | Produksi tahun terpilih per `material_type` |
| 2 | Dice | Tahun + region + material_type terpilih, per kuartal dan `material_name` |
| 3 | Roll-up | `GROUP BY ROLLUP (year, quarter, month)` pada produksi |
| 4a-4c | Drill-down | Region, lalu site dalam region, lalu material per site |
| 5 | Pivot | `PIVOT` dinamis: produksi per bulan x `material_name` (Coal, Copper, Gold, Iron, Nickel) |
| 6 | Drill-across | Produksi, peralatan, dan keuangan per bulan (tiap fakta diagregasi sendiri dulu, tanpa fan-out), memakai tahun irisan ketiga fakta (2025) |
| 7 | Coverage | Cakupan data per tahun untuk tiga tabel fakta |
| 8 | Pembanding README | Produksi per `material_type` untuk tahun >= 2025 |

### A.1 Bukti kesesuaian dengan README

Bagian 8 (produksi tahun >= 2025):

| material_type | total_produksi | Angka README |
|---|---|---|
| Metal | 434.721,00 | 434.721 |
| Ore | 112.687,00 | 112.687 |

Self-test di akhir `olap.sql` (total hasil ROLLUP sama dengan total langsung): **PASS** (596.200,00 = 596.200,00).

Konsistensi antar level untuk 2027: slice (Metal 156.475 + Ore 41.482) = drill-down 4a (Sumatera 90.306 + Kalimantan 86.472 + Papua 21.179) = baris 2027 pada roll-up = 197.957.

Bagian 6 untuk Mei 2025 menghasilkan `rata_efisiensi` = 0,956029, sama dengan 95,60% pada `validate.sql` (WARN no. 53, selisih 0,06 poin terhadap 95,66% di README).

### A.2 Temuan karakteristik data (tidak mengubah hasil README)

Cakupan tahun per tabel fakta (bagian 7):

| year | produksi | jam_operasi | realisasi_biaya |
|---|---|---|---|
| 2022 | 48.792 | 36.293.213 | 7.399.407.166 |
| 2025 | 110.971 | 36.293.213 | 5.445.764.033 |
| 2026 | 150.218 | kosong | kosong |
| 2027 | 197.957 | kosong | kosong |
| 2028 | 88.262 | kosong | kosong |

1. **Data tidak kontinu.** Produksi ada di 2022 dan 2025-2028; peralatan dan keuangan hanya di 2022 dan 2025 (pada 2025, peralatan hanya Mei dan keuangan Mei-Agustus). Tidak ada data untuk 2024, sehingga kueri dashboard bawaan repo dengan `WHERE t.year = 2024` tidak mengembalikan baris. Ini sifat data sumber, bukan galat ETL.
2. **Total `jam_operasi` 2022 dan 2025 identik (36.293.213,00).** Penjelasan ada di bagian 8, baris 3 (lihat bagian 8, baris 3): masing-masing tahun memuat 118.446 baris peralatan (236.892 = 2 x 118.446) dan diduga blok 2025 adalah salinan blok 2022 dari proses pembangkit data. Data ini sumber angka README, sehingga tidak diubah. Temuan WARN no. 64-68 (rasio baris terhadap kunci bisnis unik) adalah catatan DQ terpisah pada kolom ID.
3. **Fan-out pada kueri dashboard bawaan.** Kueri 4 dan 5 di `dashboard/corrected_dashboard_queries.sql` melakukan `LEFT JOIN` tiga tabel fakta dalam satu `GROUP BY`, sehingga `SUM` berpotensi menggembung. `olap.sql` menghindarinya dengan agregasi per fakta terlebih dulu.
4. **Kendala teknis:** `sqlcmd` memulai sesi dengan `QUOTED_IDENTIFIER OFF`, sedangkan metode XML `.value()` (dipakai untuk pivot dinamis) mewajibkan `ON`. Solusi: `SET QUOTED_IDENTIFIER ON;` di awal `olap.sql`.

