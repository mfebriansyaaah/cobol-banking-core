@echo off
REM Build Script untuk COBOL MySQL Backend (Windows)
REM Usage: build.bat

echo ==========================================
echo   Building COBOL MySQL Backend (Windows)
echo ==========================================

REM Cek apakah cobc tersedia
where cobc >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: GnuCOBOL (cobc) tidak ditemukan di PATH
    echo Install GnuCOBOL dari: https://sourceforge.net/projects/gnucobol/files/
    exit /b 1
)

REM Path MySQL ODBC Driver (default)
set MYSQL_ODBC_PATH=C:\Program Files\MySQL\Connector ODBC 8.0
if not exist "%MYSQL_ODBC_PATH%\include\sql.h" (
    set MYSQL_ODBC_PATH=C:\Program Files (x86)\MySQL\Connector ODBC 8.0
)
if not exist "%MYSQL_ODBC_PATH%\include\sql.h" (
    echo WARNING: MySQL ODBC Driver tidak ditemukan di path default
    echo Pastikan MySQL Connector/ODBC 8.0 sudah terinstall
    echo Mencari di path alternatif...
    
    REM Coba cari di registry atau path lain
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\MySQL\MySQL Connector/ODBC 8.0" /v "Location" 2^>nul') do (
        set MYSQL_ODBC_PATH=%%B
    )
)

echo Using MySQL ODBC at: %MYSQL_ODBC_PATH%

REM Kompilasi
echo Compiling...
cobc -x -o cobol\bin\main_logic.exe cobol\src\main_logic.cob ^
    -I"%MYSQL_ODBC_PATH%\include" ^
    -L"%MYSQL_ODBC_PATH%\lib" ^
    -lodbc32 ^
    -Wall -Wextra -O2

if exist cobol\bin\main_logic.exe (
    echo SUCCESS: Binary dibuat di cobol\bin\main_logic.exe
    for %%F in (cobol\bin\main_logic.exe) do echo Size: %%~zF bytes
) else (
    echo ERROR: Kompilasi gagal
    exit /b 1
)

echo ==========================================
echo Build completed successfully!
echo ==========================================
echo.
echo Next steps:
echo 1. Setup database: mysql -u root -p ^< database\schema.sql
echo 2. Konfigurasi ODBC (lihat cobol\config\README.md)
echo 3. Test COBOL: cobol\bin\main_logic.exe GET_USER 1
echo 4. Jalankan Node.js: cd middleware ^&^& npm install ^&^& npm start
echo.
pause