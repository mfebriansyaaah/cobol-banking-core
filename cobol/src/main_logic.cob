IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN_LOGIC.
       AUTHOR. COBOL BACKEND TEAM.
       DATE-WRITTEN. 2026-10-03.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. X86-64.
       OBJECT-COMPUTER. X86-64.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       * ---------------------------------------------------------
       * SQLCA - SQL Communication Area (untuk error handling)
       * ---------------------------------------------------------
       EXEC SQL INCLUDE SQLCA END-EXEC.

       * ---------------------------------------------------------
       * Variabel Koneksi Database
       * ---------------------------------------------------------
       01  DB-CONNECTION.
           05  DSN-NAME      PIC X(30) VALUE "COBOL_MYSQL".
           05  DB-USER       PIC X(30) VALUE "cobol_user".
           05  DB-PASS       PIC X(30) VALUE "cobol_pass".

       * ---------------------------------------------------------
       * Variabel Argumen Command Line
       * ---------------------------------------------------------
       01  CMD-ARGS.
           05  CMD-ACTION    PIC X(20) VALUE SPACES.
           05  CMD-PARAM1    PIC X(50) VALUE SPACES.
           05  CMD-PARAM2    PIC X(50) VALUE SPACES.

       * ---------------------------------------------------------
       * Variabel Data User
       * ---------------------------------------------------------
       01  USER-RECORD.
           05  WS-USER-ID       PIC 9(10) VALUE ZERO.
           05  WS-USERNAME      PIC X(50) VALUE SPACES.
           05  WS-EMAIL         PIC X(100) VALUE SPACES.
           05  WS-FULL-NAME     PIC X(100) VALUE SPACES.
           05  WS-STATUS        PIC X(10) VALUE SPACES.

       * ---------------------------------------------------------
       * Variabel Data Product
       * ---------------------------------------------------------
       01  PRODUCT-RECORD.
           05  WS-PROD-ID       PIC 9(10) VALUE ZERO.
           05  WS-PROD-CODE     PIC X(20) VALUE SPACES.
           05  WS-PROD-NAME     PIC X(100) VALUE SPACES.
           05  WS-PRICE         PIC 9(10)V99 VALUE ZERO.
           05  WS-STOCK         PIC 9(10) VALUE ZERO.
           05  WS-CATEGORY      PIC X(50) VALUE SPACES.

       * ---------------------------------------------------------
       * Variabel Kontrol & Utility
       * ---------------------------------------------------------
       01  WS-EXIT-CODE       PIC 9(2) VALUE 0.
           88  EXIT-SUCCESS        VALUE 0.
           88  EXIT-NOT-FOUND      VALUE 1.
           88  EXIT-DB-ERROR       VALUE 2.
           88  EXIT-INVALID-CMD    VALUE 3.
           88  EXIT-INVALID-ARG    VALUE 4.

       01  WS-ROW-COUNT       PIC 9(5) VALUE ZERO.
       01  WS-SQL-STATE       PIC X(5) VALUE SPACES.
       01  WS-ERR-MSG         PIC X(255) VALUE SPACES.
       01  WS-OUTPUT-LINE     PIC X(500) VALUE SPACES.
       01  WS-FORMATTED-PRICE PIC X(20) VALUE SPACES.

       * ---------------------------------------------------------
       * Cursor untuk SELECT multiple rows
       * ---------------------------------------------------------
       EXEC SQL DECLARE USER_CURSOR CURSOR FOR
           SELECT id, username, email, full_name, status
           FROM users
           WHERE status = :WS-STATUS-FILTER
       END-EXEC.

       EXEC SQL DECLARE PRODUCT_CURSOR CURSOR FOR
           SELECT id, product_code, product_name, price, stock, category
           FROM products
           WHERE category = :WS-CATEGORY-FILTER OR :WS-CATEGORY-FILTER = 'ALL'
       END-EXEC.

       01  WS-STATUS-FILTER   PIC X(10) VALUE 'Active'.
       01  WS-CATEGORY-FILTER PIC X(50) VALUE 'ALL'.

       LINKAGE SECTION.
       01  LS-ARG-COUNT       PIC 9(4) COMP-5.
       01  LS-ARG-VALUE       PIC X(100) OCCURS 10 TIMES.

       PROCEDURE DIVISION USING LS-ARG-COUNT LS-ARG-VALUE.
       MAIN-SECTION.
           * ---------------------------------------------------------
           * Inisialisasi & Parsing Argumen
           * ---------------------------------------------------------
           PERFORM INITIALIZE-VARIABLES.
           PERFORM PARSE-ARGUMENTS.
           PERFORM VALIDATE-ACTION.

           * ---------------------------------------------------------
           * Koneksi ke Database
           * ---------------------------------------------------------
           PERFORM CONNECT-DATABASE.
           IF NOT EXIT-SUCCESS
               PERFORM DISPLAY-ERROR
               GO TO PROGRAM-EXIT.

           * ---------------------------------------------------------
           * Routing Action
           * ---------------------------------------------------------
           EVALUATE TRUE
               WHEN CMD-ACTION = 'GET_USER'
                   PERFORM ACTION-GET-USER
               WHEN CMD-ACTION = 'LIST_USERS'
                   PERFORM ACTION-LIST-USERS
               WHEN CMD-ACTION = 'GET_PRODUCT'
                   PERFORM ACTION-GET-PRODUCT
               WHEN CMD-ACTION = 'LIST_PRODUCTS'
                   PERFORM ACTION-LIST-PRODUCTS
               WHEN CMD-ACTION = 'CREATE_USER'
                   PERFORM ACTION-CREATE-USER
               WHEN CMD-ACTION = 'UPDATE_USER'
                   PERFORM ACTION-UPDATE-USER
               WHEN OTHER
                   MOVE 3 TO WS-EXIT-CODE
                   DISPLAY "ERROR|INVALID_ACTION|Action tidak dikenali: " CMD-ACTION
           END-EVALUATE.

           * ---------------------------------------------------------
           * Tutup Koneksi & Exit
           * ---------------------------------------------------------
           PERFORM DISCONNECT-DATABASE.
           GO TO PROGRAM-EXIT.

       * =========================================================
       * SUB-ROUTINES
       * =========================================================

       INITIALIZE-VARIABLES.
           MOVE ZERO TO WS-EXIT-CODE.
           MOVE SPACES TO CMD-ACTION, CMD-PARAM1, CMD-PARAM2.
           MOVE SPACES TO WS-OUTPUT-LINE.

       PARSE-ARGUMENTS.
           * Argumen 1: Action (wajib)
           IF LS-ARG-COUNT >= 2
               MOVE LS-ARG-VALUE(2) TO CMD-ACTION
           ELSE
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_ACTION|Argumen action wajib diisi"
               GO TO PROGRAM-EXIT.
           * Argumen 2: Parameter 1 (opsional)
           IF LS-ARG-COUNT >= 3
               MOVE LS-ARG-VALUE(3) TO CMD-PARAM1.
           * Argumen 3: Parameter 2 (opsional)
           IF LS-ARG-COUNT >= 4
               MOVE LS-ARG-VALUE(4) TO CMD-PARAM2.

       VALIDATE-ACTION.
           * Validasi sederhana: action tidak boleh mengandung karakter berbahaya
           INSPECT CMD-ACTION TALLYING WS-ROW-COUNT
               FOR ALL ";"
           IF WS-ROW-COUNT > 0
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|INVALID_ACTION|Karakter terlarang di action"
               GO TO PROGRAM-EXIT.

       CONNECT-DATABASE.
           EXEC SQL
               CONNECT TO :DSN-NAME USER :DB-USER USING :DB-PASS
           END-EXEC.
           IF SQLCODE NOT = 0
               MOVE 2 TO WS-EXIT-CODE
               MOVE "Koneksi database gagal" TO WS-ERR-MSG
               PERFORM CAPTURE-SQL-ERROR.

       DISCONNECT-DATABASE.
           EXEC SQL
               DISCONNECT :DSN-NAME
           END-EXEC.

       CAPTURE-SQL-ERROR.
           * Ambil detail error dari SQLCA
           MOVE SQLSTATE TO WS-SQL-STATE.
           STRING "SQLSTATE: " WS-SQL-STATE " | SQLCODE: " SQLCODE
               " | MSG: " SQLERRMC
               DELIMITED BY SIZE INTO WS-ERR-MSG.
           DISPLAY "ERROR|DB_ERROR|" WS-ERR-MSG.

       DISPLAY-ERROR.
           * Error sudah di-display di CAPTURE-SQL-ERROR atau validasi
           CONTINUE.

       * =========================================================
       * ACTION: GET_USER - Ambil 1 user by ID
       * =========================================================
       ACTION-GET-USER.
           IF CMD-PARAM1 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|User ID wajib diisi untuk GET_USER"
               GO TO PROGRAM-EXIT.

           EXEC SQL
               SELECT id, username, email, full_name, status
               INTO :WS-USER-ID, :WS-USERNAME, :WS-EMAIL, :WS-FULL-NAME, :WS-STATUS
               FROM users
               WHERE id = :CMD-PARAM1
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   * Sukses - Format output: ID|USERNAME|EMAIL|FULL_NAME|STATUS
                   STRING WS-USER-ID "|" WS-USERNAME "|" WS-EMAIL "|"
                       WS-FULL-NAME "|" WS-STATUS
                       DELIMITED BY SIZE INTO WS-OUTPUT-LINE
                   DISPLAY WS-OUTPUT-LINE
               WHEN 100
                   MOVE 1 TO WS-EXIT-CODE
                   DISPLAY "ERROR|NOT_FOUND|User dengan ID " CMD-PARAM1 " tidak ditemukan"
               WHEN OTHER
                   MOVE 2 TO WS-EXIT-CODE
                   PERFORM CAPTURE-SQL-ERROR
           END-EVALUATE.

       * =========================================================
       * ACTION: LIST_USERS - List semua user (filter by status)
       * =========================================================
       ACTION-LIST-USERS.
           * Parameter opsional: status filter (default: Active)
           IF CMD-PARAM1 NOT = SPACES
               MOVE CMD-PARAM1 TO WS-STATUS-FILTER.

           EXEC SQL
               OPEN USER_CURSOR
           END-EXEC.
           IF SQLCODE NOT = 0
               MOVE 2 TO WS-EXIT-CODE
               PERFORM CAPTURE-SQL-ERROR
               GO TO PROGRAM-EXIT.

           MOVE ZERO TO WS-ROW-COUNT.
           PERFORM FETCH-USER-LOOP UNTIL SQLCODE = 100.

           EXEC SQL
               CLOSE USER_CURSOR
           END-EXEC.

           IF WS-ROW-COUNT = 0
               MOVE 1 TO WS-EXIT-CODE
               DISPLAY "ERROR|NOT_FOUND|Tidak ada user dengan status " WS-STATUS-FILTER.

       FETCH-USER-LOOP.
           EXEC SQL
               FETCH USER_CURSOR
               INTO :WS-USER-ID, :WS-USERNAME, :WS-EMAIL, :WS-FULL-NAME, :WS-STATUS
           END-EXEC.
           IF SQLCODE = 0
               ADD 1 TO WS-ROW-COUNT
               STRING WS-USER-ID "|" WS-USERNAME "|" WS-EMAIL "|"
                   WS-FULL-NAME "|" WS-STATUS
                   DELIMITED BY SIZE INTO WS-OUTPUT-LINE
               DISPLAY WS-OUTPUT-LINE.

       * =========================================================
       * ACTION: GET_PRODUCT - Ambil 1 product by ID
       * =========================================================
       ACTION-GET-PRODUCT.
           IF CMD-PARAM1 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Product ID wajib diisi untuk GET_PRODUCT"
               GO TO PROGRAM-EXIT.

           EXEC SQL
               SELECT id, product_code, product_name, price, stock, category
               INTO :WS-PROD-ID, :WS-PROD-CODE, :WS-PROD-NAME, :WS-PRICE, :WS-STOCK, :WS-CATEGORY
               FROM products
               WHERE id = :CMD-PARAM1
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   * Format price: 15000000.00 -> 15000000.00
                   MOVE WS-PRICE TO WS-FORMATTED-PRICE
                   STRING WS-PROD-ID "|" WS-PROD-CODE "|" WS-PROD-NAME "|"
                       WS-FORMATTED-PRICE "|" WS-STOCK "|" WS-CATEGORY
                       DELIMITED BY SIZE INTO WS-OUTPUT-LINE
                   DISPLAY WS-OUTPUT-LINE
               WHEN 100
                   MOVE 1 TO WS-EXIT-CODE
                   DISPLAY "ERROR|NOT_FOUND|Product dengan ID " CMD-PARAM1 " tidak ditemukan"
               WHEN OTHER
                   MOVE 2 TO WS-EXIT-CODE
                   PERFORM CAPTURE-SQL-ERROR
           END-EVALUATE.

       * =========================================================
       * ACTION: LIST_PRODUCTS - List products (filter by category)
       * =========================================================
       ACTION-LIST-PRODUCTS.
           IF CMD-PARAM1 NOT = SPACES
               MOVE CMD-PARAM1 TO WS-CATEGORY-FILTER
           ELSE
               MOVE 'ALL' TO WS-CATEGORY-FILTER.

           EXEC SQL
               OPEN PRODUCT_CURSOR
           END-EXEC.
           IF SQLCODE NOT = 0
               MOVE 2 TO WS-EXIT-CODE
               PERFORM CAPTURE-SQL-ERROR
               GO TO PROGRAM-EXIT.

           MOVE ZERO TO WS-ROW-COUNT.
           PERFORM FETCH-PRODUCT-LOOP UNTIL SQLCODE = 100.

           EXEC SQL
               CLOSE PRODUCT_CURSOR
           END-EXEC.

           IF WS-ROW-COUNT = 0
               MOVE 1 TO WS-EXIT-CODE
               DISPLAY "ERROR|NOT_FOUND|Tidak ada product untuk kategori " WS-CATEGORY-FILTER.

       FETCH-PRODUCT-LOOP.
           EXEC SQL
               FETCH PRODUCT_CURSOR
               INTO :WS-PROD-ID, :WS-PROD-CODE, :WS-PROD-NAME, :WS-PRICE, :WS-STOCK, :WS-CATEGORY
           END-EXEC.
           IF SQLCODE = 0
               ADD 1 TO WS-ROW-COUNT
               MOVE WS-PRICE TO WS-FORMATTED-PRICE
               STRING WS-PROD-ID "|" WS-PROD-CODE "|" WS-PROD-NAME "|"
                   WS-FORMATTED-PRICE "|" WS-STOCK "|" WS-CATEGORY
                   DELIMITED BY SIZE INTO WS-OUTPUT-LINE
               DISPLAY WS-OUTPUT-LINE.

       * =========================================================
       * ACTION: CREATE_USER - Buat user baru
       * =========================================================
       ACTION-CREATE-USER.
           * Parameter: username|email|full_name|status
           IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Format: CREATE_USER \"username|email|full_name\" [status]"
               GO TO PROGRAM-EXIT.

           * Parse parameter (sederhana, asumsikan dipisahkan | )
           * Untuk production, parsing ini harus lebih robust di Node.js
           EXEC SQL
               INSERT INTO users (username, email, full_name, status)
               VALUES (:CMD-PARAM1, :CMD-PARAM2, :CMD-PARAM3, COALESCE(:CMD-PARAM4, 'Active'))
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   * Ambil ID yang baru dibuat
                   EXEC SQL
                       SELECT LAST_INSERT_ID() INTO :WS-USER-ID
                   END-EXEC.
                   STRING "SUCCESS|USER_CREATED|" WS-USER-ID "|" CMD-PARAM1
                       DELIMITED BY SIZE INTO WS-OUTPUT-LINE
                   DISPLAY WS-OUTPUT-LINE
               WHEN OTHER
                   MOVE 2 TO WS-EXIT-CODE
                   PERFORM CAPTURE-SQL-ERROR
           END-EVALUATE.

       * =========================================================
       * ACTION: UPDATE_USER - Update user
       * =========================================================
       ACTION-UPDATE-USER.
           * Parameter: user_id|field|value
           IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES OR CMD-PARAM3 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Format: UPDATE_USER user_id field value"
               GO TO PROGRAM-EXIT.

           * Dynamic SQL sederhana (untuk demo, production pakai prepared statement)
           * Catatan: GnuCOBOL tidak support dynamic SQL penuh, gunakan EVALUATE
           EVALUATE TRUE
               WHEN CMD-PARAM2 = 'email'
                   EXEC SQL
                       UPDATE users SET email = :CMD-PARAM3 WHERE id = :CMD-PARAM1
                   END-EXEC
               WHEN CMD-PARAM2 = 'full_name'
                   EXEC SQL
                       UPDATE users SET full_name = :CMD-PARAM3 WHERE id = :CMD-PARAM1
                   END-EXEC
               WHEN CMD-PARAM2 = 'status'
                   EXEC SQL
                       UPDATE users SET status = :CMD-PARAM3 WHERE id = :CMD-PARAM1
                   END-EXEC
               WHEN OTHER
                   MOVE 4 TO WS-EXIT-CODE
                   DISPLAY "ERROR|INVALID_FIELD|Field tidak didukung: " CMD-PARAM2
                   GO TO PROGRAM-EXIT
           END-EVALUATE.

           EVALUATE SQLCODE
               WHEN 0
                   IF SQLERRD(3) = 0
                       MOVE 1 TO WS-EXIT-CODE
                       DISPLAY "ERROR|NOT_FOUND|User dengan ID " CMD-PARAM1 " tidak ditemukan"
                   ELSE
                       DISPLAY "SUCCESS|USER_UPDATED|" CMD-PARAM1
                   END-IF
               WHEN OTHER
                   MOVE 2 TO WS-EXIT-CODE
                   PERFORM CAPTURE-SQL-ERROR
           END-EVALUATE.

       PROGRAM-EXIT.
           STOP RUN WS-EXIT-CODE.