#!/bin/bash
# Build Script untuk COBOL MySQL Backend
# Usage: ./build.sh [windows|linux]

set -e

PLATFORM=${1:-linux}
COBOL_SRC="cobol/src/main_logic.cob"
COBOL_BIN="cobol/bin/main_logic"

echo "=========================================="
echo "  Building COBOL MySQL Backend"
echo "  Platform: $PLATFORM"
echo "=========================================="

# Cek apakah cobc tersedia
if ! command -v cobc &> /dev/null; then
    echo "ERROR: GnuCOBOL (cobc) tidak ditemukan di PATH"
    echo "Install: sudo apt-get install gnucobol (Linux) atau download dari sourceforge (Windows)"
    exit 1
fi

# Cek MySQL ODBC Driver
if [ "$PLATFORM" = "windows" ]; then
    MYSQL_ODBC_PATH="/c/Program Files/MySQL/Connector ODBC 8.0"
    if [ ! -d "$MYSQL_ODBC_PATH" ]; then
        MYSQL_ODBC_PATH="/c/Program Files (x86)/MySQL/Connector ODBC 8.0"
    fi
    
    if [ ! -d "$MYSQL_ODBC_PATH" ]; then
        echo "WARNING: MySQL ODBC Driver tidak ditemukan di path standar"
        echo "Pastikan MySQL Connector/ODBC 8.0 sudah terinstall"
    fi
    
    echo "Compiling for Windows..."
    cobc -x -o "${COBOL_BIN}.exe" "$COBOL_SRC" \
        -I"${MYSQL_ODBC_PATH}/include" \
        -L"${MYSQL_ODBC_PATH}/lib" \
        -lodbc32 \
        -Wall -Wextra -O2
    
    if [ -f "${COBOL_BIN}.exe" ]; then
        echo "SUCCESS: Binary dibuat di ${COBOL_BIN}.exe"
        echo "Size: $(ls -lh ${COBOL_BIN}.exe | awk '{print $5}')"
    else
        echo "ERROR: Kompilasi gagal"
        exit 1
    fi

else
    # Linux
    echo "Compiling for Linux..."
    
    # Cek library ODBC
    if ! ldconfig -p | grep -q libodbc; then
        echo "WARNING: unixODBC tidak terdeteksi"
        echo "Install: sudo apt-get install unixodbc unixodbc-dev"
    fi
    
    if ! ldconfig -p | grep -q libmyodbc; then
        echo "WARNING: MySQL ODBC Driver (libmyodbc) tidak terdeteksi"
        echo "Install: sudo apt-get install libmyodbc8w"
    fi
    
    cobc -x -o "$COBOL_BIN" "$COBOL_SRC" \
        -lodbc \
        -Wall -Wextra -O2
    
    if [ -f "$COBOL_BIN" ]; then
        echo "SUCCESS: Binary dibuat di $COBOL_BIN"
        echo "Size: $(ls -lh $COBOL_BIN | awk '{print $5}')"
        chmod +x "$COBOL_BIN"
    else
        echo "ERROR: Kompilasi gagal"
        exit 1
    fi
fi

echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Setup database: mysql -u root -p < database/schema.sql"
echo "2. Konfigurasi ODBC (lihat cobol/config/README.md)"
echo "3. Test COBOL: ./cobol/bin/main_logic GET_USER 1"
echo "4. Jalankan Node.js: cd middleware && npm install && npm start"