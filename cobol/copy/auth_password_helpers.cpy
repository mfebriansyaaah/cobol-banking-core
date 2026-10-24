        COMPUTE-HASH-LEN.            *> Length up to the NUL that the C hash function writes.
            MOVE 1 TO WS-HLEN
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 256 OR WS-HLEN > 1
                IF WS-HASH(WS-I:1) = LOW-VALUE
                    COMPUTE WS-HLEN = WS-I - 1
                END-IF
            END-PERFORM
            IF WS-HLEN < 1
                MOVE 1 TO WS-HLEN
            END-IF.

        CHECK-PASSWORD-BLOCKLIST.
            *> WS-PLAIN holds the candidate; the deny list is keyed by the
            *> SHA-256 hex of the lowercased value, so matching is
            *> case-insensitive. Sets WS-PW-BLOCKED / WS-PW-DBERR.
            MOVE WS-PLAIN TO WS-PW-LOWER
            INSPECT WS-PW-LOWER CONVERTING
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ" TO "abcdefghijklmnopqrstuvwxyz"
            CALL "sha256_hex_lower" USING BY REFERENCE WS-PW-LOWER BY REFERENCE WS-PW-HASH BY VALUE 64 END-CALL
            MOVE "SELECT 1 FROM password_blocklist WHERE hash = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PW-HASH TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 1 TO WS-PW-DBERR
                EXIT PARAGRAPH
            END-IF.
            MOVE 1 TO WS-PW-BLOCKED
            EXIT PARAGRAPH.

        VERIFY-HISTORY-HASH.
            *> WS-PW-HIST-HASH holds a stored hash; verify WS-PLAIN against it.
            IF WS-PW-HIST-HASH = SPACES
                EXIT PARAGRAPH
            END-IF.
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-PW-HIST-HASH BY REFERENCE WS-VERIFY END-CALL
            IF WS-VERIFY = "1"
                MOVE 1 TO WS-PW-REUSED
            END-IF.
            EXIT PARAGRAPH.

        CHECK-PASSWORD-HISTORY.
            *> p1 = email; WS-PLAIN holds the candidate. Refuses a password
            *> equal to the current one or to one of the last
            *> PASSWORD_HISTORY_COUNT entries (0 disables the check).
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "PASSWORD_HISTORY_COUNT" BY REFERENCE "5" BY REFERENCE WS-CD-STR END-CALL
            IF WS-CD-STR(1:1) < "1" OR WS-CD-STR(1:1) > "9"
                EXIT PARAGRAPH
            END-IF.
            *> The current password is the most recent entry even for an
            *> account created before the history existed.
            MOVE "SELECT password_hash FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 1 TO WS-PW-DBERR
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:256) TO WS-PW-HIST-HASH
            PERFORM VERIFY-HISTORY-HASH
            IF WS-PW-REUSED = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT h.password_hash FROM password_history h JOIN users u ON u.id = h.user_id WHERE u.email = ? ORDER BY h.created_at DESC, h.id DESC LIMIT " WS-CD-STR DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 1 TO WS-PW-DBERR
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE 1 TO WS-HP
            PERFORM UNTIL WS-HP > WS-RLEN OR WS-PW-REUSED = 1
                MOVE SPACES TO WS-PW-HIST-HASH
                UNSTRING WS-RESULT(1:WS-RLEN) DELIMITED BY ";"
                    INTO WS-PW-HIST-HASH WITH POINTER WS-HP
                END-UNSTRING
                PERFORM VERIFY-HISTORY-HASH
            END-PERFORM
            EXIT PARAGRAPH.

        CHECK-PASSWORD-POLICY.
            *> Blocklist first, then history. DB failures are reported, never
            *> silently treated as an accepted password.
            MOVE 0 TO WS-PW-BLOCKED
            MOVE 0 TO WS-PW-REUSED
            MOVE 0 TO WS-PW-DBERR
            PERFORM CHECK-PASSWORD-BLOCKLIST
            IF WS-PW-BLOCKED = 1 OR WS-PW-DBERR = 1
                EXIT PARAGRAPH
            END-IF.
            PERFORM CHECK-PASSWORD-HISTORY
            EXIT PARAGRAPH.

        RECORD-PASSWORD-HISTORY.
            *> p1 = email; WS-HASH holds the newly stored hash. Append it and
            *> keep only the last PASSWORD_HISTORY_COUNT rows. Runs inside the
            *> password-change transaction, so a failure rolls the change back.
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "PASSWORD_HISTORY_COUNT" BY REFERENCE "5" BY REFERENCE WS-CD-STR END-CALL
            IF WS-CD-STR(1:1) < "1" OR WS-CD-STR(1:1) > "9"
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO password_history (user_id, password_hash) SELECT id, ? FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-HASH TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-PREP-SQL
            STRING "DELETE FROM password_history WHERE user_id = (SELECT id FROM users WHERE email = ?) AND id NOT IN (SELECT id FROM (SELECT id FROM password_history WHERE user_id = (SELECT id FROM users WHERE email = ?) ORDER BY created_at DESC, id DESC LIMIT " WS-CD-STR ") t)" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

