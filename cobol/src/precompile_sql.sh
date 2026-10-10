#!/bin/bash

# Simple COBOL SQL Pre-compiler
# Usage: ./precompile_sql.sh source.cob target.cob

SOURCE=$1
TARGET=$2

if [ -z "$SOURCE" ] || [ -z "$TARGET" ]; then
    echo "Usage: $0 <source.cob> <target.cob>"
    exit 1
fi

# 1. Remove EXEC SQL INCLUDE SQLCA
# 2. Convert EXEC SQL SELECT ... INTO :var END-EXEC 
#    to CALL "SQL_EXECUTE" USING query, var
# 3. Convert EXEC SQL UPDATE/INSERT/DELETE END-EXEC
#    to CALL "SQL_EXECUTE" USING query, var

# This is a simplified regex-based replacement. 
# In a real world, this would be a full lexer/parser.

sed -E 's/EXEC SQL INCLUDE SQLCA END-EXEC//g' "$SOURCE" | \
sed -E 's/EXEC SQL ([^C]+) END-EXEC/CALL "SQL_EXECUTE" USING "\1", WS-OUTPUT-MSG/g' > "$TARGET"

echo "Pre-compiled $SOURCE to $TARGET"
