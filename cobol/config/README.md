# Panduan Konfigurasi ODBC untuk COBOL-MySQL

## Prasyarat
1. **MySQL Server** sudah terinstall dan berjalan
2. **MySQL Connector/ODBC 8.0** sudah terinstall
   - Download: https://dev.mysql.com/downloads/connector/odbc/
   - Pilih versi **Unicode** (direkomendasikan) atau ANSI

## Setup di Windows

### 1. Install MySQL ODBC Driver
- Jalankan installer `mysql-connector-odbc-8.0.x-win64.msi`
- Catat path instalasi (default: `C:\Program Files\MySQL\Connector ODBC 8.0\`)

### 2. Konfigurasi DSN (Data Source Name)
**Opsi A: Menggunakan ODBC Data Source Administrator (GUI)**
1. Buka "ODBC Data Sources (64-bit)" dari Start Menu
2. Tab **System DSN** → Klik **Add**
3. Pilih **MySQL ODBC 8.0 Unicode Driver** → Finish
4. Isi konfigurasi:
   - **Data Source Name**: `COBOL_MYSQL`
   - **Description**: `MySQL connection for COBOL Application`
   - **Server**: `localhost`
   - **Port**: `3306`
   - **User**: `cobol_user` (atau user MySQL Anda)
   - **Password**: `cobol_pass` (atau password Anda)
   - **Database**: `cobol_db`
5. Klik **Test** → **OK**

**Opsi B: Menggunakan File Konfigurasi (Manual)**
1. Copy file `odbc.ini` dan `odbcinst.ini` dari folder `cobol/config/` ke:
   - `C:\Windows\System32\` (untuk 64-bit)
   - `C:\Windows\SysWOW64\` (untuk 32-bit)
2. Edit path `Driver` di `odbcinst.ini` sesuai lokasi instalasi MySQL ODBC Driver Anda

### 3. Verifikasi Koneksi
Buka Command Prompt dan jalankan:
```cmd
isql COBOL_MYSQL cobol_user cobol_pass
```
Jika berhasil, akan muncul prompt `SQL>`.

## Setup di Linux (Ubuntu/Debian)

```bash
# Install driver
sudo apt-get update
sudo apt-get install unixodbc unixodbc-dev odbcinst libmyodbc8w

# Konfigurasi odbcinst.ini (sudah disediakan di cobol/config/)
sudo cp cobol/config/odbcinst.ini /etc/odbcinst.ini

# Konfigurasi odbc.ini
sudo cp cobol/config/odbc.ini /etc/odbc.ini

# Test koneksi
isql -v COBOL_MYSQL cobol_user cobol_pass
```

## Catatan Penting untuk COBOL

### Environment Variables
Set environment variable sebelum mengompilasi/menjalankan COBOL:
```cmd
REM Windows
set ODBCINI=C:\path\to\cobol\config\odbc.ini
set ODBCINSTINI=C:\path\to\cobol\config\odbcinst.ini

# Linux
export ODBCINI=/path/to/cobol/config/odbc.ini
export ODBCINSTINI=/path/to/cobol/config/odbcinst.ini
```

### Kompilasi GnuCOBOL dengan cob-odbc
```bash
# Windows (menggunakan cobc)
cobc -x -o bin/main_logic.exe src/main_logic.cob -I"C:\Program Files\MySQL\Connector ODBC 8.0\include" -L"C:\Program Files\MySQL\Connector ODBC 8.0\lib" -lodbc32

# Linux
cobc -x -o bin/main_logic src/main_logic.cob -lodbc
```

## Troubleshooting

| Error | Solusi |
|-------|--------|
| `Data source name not found` | Pastikan DSN terdaftar di ODBC Administrator atau file odbc.ini terbaca |
| `Driver not found` | Periksa path `Driver` di `odbcinst.ini` |
| `Access denied` | Periksa user/password MySQL, pastikan user punya hak akses ke database `cobol_db` |
| `Unknown database` | Jalankan `database/schema.sql` terlebih dahulu |

## Struktur File Konfigurasi
```
cobol/
├── config/
│   ├── odbc.ini          # DSN Configuration (copy ke system atau set ODBCINI)
│   └── odbcinst.ini      # Driver Configuration (copy ke system atau set ODBCINSTINI)
```