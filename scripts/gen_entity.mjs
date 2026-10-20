#!/usr/bin/env node
// Generated reference-data module for the 7-day volume sprint.
// Reads data/entities.json and emits:
//   - cobol/src/ref_core.cob
//   - database/migrations/0047_ref_entities.sql
//   - middleware/src/routes/ref.js
//   - tests/lab/test_ref_<entity>.sh
//   - the generated dispatch block inside cobol/src/main_logic.cob
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const data = JSON.parse(fs.readFileSync(path.join(root, 'data/entities.json'), 'utf8'));
const entities = data.entities || [];
if (entities.length === 0) {
  console.error('no entities in data/entities.json');
  process.exit(1);
}

const ACTIONS = ['LIST', 'GET', 'CREATE', 'UPDATE', 'DEACT'];
const action = (e, a) => `REF_${e.code}_${a}`;

function write(rel, content) {
  const full = path.join(root, rel);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
}

function dispatchBlock() {
  return entities.map((e) => ACTIONS.map((a) => {
    const name = action(e, a);
    return `            ELSE IF CMD-ACTION(1:${name.length}) = "${name}"\n` +
      `                CALL "ref_core" USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6 WS-OUTPUT-MSG END-CALL\n`;
  }).join('')).join('');
}

function mainLogic() {
  const whens = entities.map((e) => ACTIONS.map((a) => {
    const name = action(e, a);
    return `                WHEN LS-CMD-ACTION(1:${name.length}) = "${name}"\n` +
      `                    PERFORM TRIM-ALL\n` +
      `                    PERFORM ACTION-${e.code}-${a}\n`;
  }).join('')).join('');
  return `        IDENTIFICATION DIVISION.
        PROGRAM-ID. ref_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  WS-BIND-5               PIC X(256) VALUE SPACES.
        01  WS-BIND-6               PIC X(256) VALUE SPACES.
        01  WS-P1-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P2-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-RLEN                 PIC 9(5) VALUE 1.
        01  WS-I                    PIC 9(3) VALUE 1.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-ERR                  PIC X(40) VALUE SPACES.
        01  WS-TOTAL                PIC X(20) VALUE SPACES.
        01  WS-LIMIT                PIC X(10) VALUE SPACES.
        01  WS-OFFSET               PIC X(10) VALUE SPACES.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ENTITY         PIC X(64) VALUE SPACES.
        01  WS-AUDIT-KEY            PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ACTION         PIC X(20) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\\".
        01  F-SEMI                  PIC X VALUE ";".
        01  F-TICK                  PIC X VALUE "\`".

        LINKAGE SECTION.
        01  LS-CMD-ACTION           PIC X(30).
        01  LS-PARAM1               PIC X(100).
        01  LS-PARAM2               PIC X(100).
        01  LS-PARAM3               PIC X(100).
        01  LS-PARAM4               PIC X(100).
        01  LS-PARAM5               PIC X(100).
        01  LS-PARAM6               PIC X(100).
        01  LS-OUTPUT-BUFFER        PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
${whens}                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.
`;
}

const COMMON = `        VALIDATE-ALL.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM5 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM6 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-ALL.
            PERFORM TRIM-P1
            PERFORM TRIM-P2
            PERFORM TRIM-P3
            PERFORM TRIM-P4
            PERFORM TRIM-P5
            PERFORM TRIM-P6.
            EXIT PARAGRAPH.

        TRIM-P1.
            MOVE LS-PARAM1 TO WS-P1-TRIMMED
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-P1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM
            IF WS-P1-LEN = 0
                MOVE 1 TO WS-P1-LEN
            END-IF.

        TRIM-P2.
            MOVE LS-PARAM2 TO WS-P2-TRIMMED
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-P2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM
            IF WS-P2-LEN = 0
                MOVE 1 TO WS-P2-LEN
            END-IF.

        TRIM-P3.
            MOVE LS-PARAM3 TO WS-P3-TRIMMED
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-P3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM
            IF WS-P3-LEN = 0
                MOVE 1 TO WS-P3-LEN
            END-IF.

        TRIM-P4.
            MOVE LS-PARAM4 TO WS-P4-TRIMMED
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-P4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM
            IF WS-P4-LEN = 0
                MOVE 1 TO WS-P4-LEN
            END-IF.

        TRIM-P5.
            MOVE LS-PARAM5 TO WS-P5-TRIMMED
            MOVE 0 TO WS-P5-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
                IF WS-P5-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P5-LEN
                END-IF
            END-PERFORM
            IF WS-P5-LEN = 0
                MOVE 1 TO WS-P5-LEN
            END-IF.

        TRIM-P6.
            MOVE LS-PARAM6 TO WS-P6-TRIMMED
            MOVE 0 TO WS-P6-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
                IF WS-P6-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P6-LEN
                END-IF
            END-PERFORM
            IF WS-P6-LEN = 0
                MOVE 1 TO WS-P6-LEN
            END-IF.

        ALLOW-ADMIN.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P6-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
                MOVE "REFERENCE" TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'REFERENCE', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            EXIT PARAGRAPH.

        AUDIT-REF.
            MOVE "INSERT INTO reference_audit (entity, entity_key, action, actor_email) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-ENTITY TO WS-BIND-1
            MOVE WS-AUDIT-KEY TO WS-BIND-2
            MOVE WS-AUDIT-ACTION TO WS-BIND-3
            MOVE WS-P6-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        TRIM-RESULT-LEN.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 16384 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.
`;

function validate(e) {
  const keyLen = e.key.length;
  return `        VALIDATE-${e.code}-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = ${keyLen}
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > ${e.label.max}
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.
`;
}

function list(e) {
  const t = e.table;
  const cols = `${e.key.column}, ':', ${e.label.column}, ':', ${e.number.column}, ':', ${e.flag.column}`;
  return `        ACTION-${e.code}-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ${t}" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(${cols}) FROM ${t} ORDER BY ${e.order} LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.
`;
}

function get(e) {
  const cols = `${e.key.column}, ':', ${e.label.column}, ':', ${e.number.column}, ':', ${e.flag.column}`;
  return `        ACTION-${e.code}-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = ${e.key.length}
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(${cols}) FROM ${e.table} WHERE ${e.key.column} = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.
`;
}

function create(e) {
  return `        ACTION-${e.code}-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-${e.code}-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN"
            MOVE "INSERT INTO ${e.table} (${e.key.column}, ${e.label.column}, ${e.number.column}, ${e.flag.column}) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "${e.table}" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
`;
}

function update(e) {
  return `        ACTION-${e.code}-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-${e.code}-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN"
            MOVE "UPDATE ${e.table} SET ${e.label.column} = ?, ${e.number.column} = ?, ${e.flag.column} = ? WHERE ${e.key.column} = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "${e.table}" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
`;
}

function deact(e) {
  return `        ACTION-${e.code}-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = ${e.key.length}
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN"
            MOVE "UPDATE ${e.table} SET ${e.flag.column} = FALSE WHERE ${e.key.column} = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "${e.table}" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
`;
}

function normalizeCalls(cob) {
  cob = cob.replace(/(CALL "SQL_PREPARE_EXEC(?:_ROWS|_LOCK)?" USING BY REFERENCE WS-PREP-SQL BY VALUE \d+\n)((?:[ \t]*BY REFERENCE [^\n]*\n)+)/g,
    (m, head) => head +
      '                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3\n' +
      '                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6\n' +
      '            END-CALL\n');
  cob = cob.replace(/(CALL "GET_RESULT" USING BY REFERENCE WS-RESULT)(?! END-CALL)/g, '$1 END-CALL');
  cob = cob.replace(/(CALL "SQL_(?:BEGIN|COMMIT|ROLLBACK)")(?! END-CALL)/g, '$1 END-CALL');
  return cob;
}

function cobol() {
  return normalizeCalls(mainLogic() + '\n' + COMMON + '\n' +
    entities.map((e) => validate(e) + '\n' + list(e) + '\n' + get(e) + '\n' + create(e) + '\n' + update(e) + '\n' + deact(e)).join('\n'));
}

function ddl(e) {
  if (!e.createTable) return '';
  return `CREATE TABLE IF NOT EXISTS ${e.table} (
    ${e.key.column} VARCHAR(${e.key.length}) PRIMARY KEY,
    ${e.label.column} VARCHAR(${e.label.max}) NOT NULL,
    ${e.number.column} INT NOT NULL DEFAULT 0,
    ${e.flag.column} BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;`;
}

function migration() {
  const tables = entities.filter((e) => e.createTable).map((e) => ddl(e)).join('\n\n');
  return `-- Generated reference-data support tables (7-day volume sprint).
CREATE TABLE IF NOT EXISTS reference_audit (
    id INT AUTO_INCREMENT PRIMARY KEY,
    entity VARCHAR(64) NOT NULL,
    entity_key VARCHAR(128) NOT NULL,
    action VARCHAR(32) NOT NULL,
    actor_email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_reference_audit_entity (entity, entity_key)
) ENGINE=InnoDB;

${tables}
`;
}

function routes() {
  const blocks = entities.map((e) => {
    const p = e.param;
    const listName = action(e, 'LIST');
    const getName = action(e, 'GET');
    const createName = action(e, 'CREATE');
    const updateName = action(e, 'UPDATE');
    const deactName = action(e, 'DEACT');
    const keyField = `{ name: '${p}', pattern: PATTERNS.REF_CODE, required: true }`;
    return `  { method: 'get', path: '${e.route}', action: '${listName}', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK,
    { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
  ] },
  { method: 'get', path: '${e.route}/:${p}', action: '${getName}', tokenIdentity: 'actor', fields: [
    ${keyField}, BLANK, BLANK, BLANK, BLANK,
    { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
  ] },
  { method: 'post', path: '${e.route}', action: '${createName}', tokenIdentity: 'actor', fields: [
    ${keyField},
    { name: 'symbol', pattern: PATTERNS.SYMBOL, required: true },
    { name: 'precision', pattern: PATTERNS.INT, required: true },
    { name: 'active', pattern: PATTERNS.FLAG, required: true },
    BLANK,
    { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
  ] },
  { method: 'put', path: '${e.route}/:${p}', action: '${updateName}', tokenIdentity: 'actor', fields: [
    ${keyField},
    { name: 'symbol', pattern: PATTERNS.SYMBOL, required: true },
    { name: 'precision', pattern: PATTERNS.INT, required: true },
    { name: 'active', pattern: PATTERNS.FLAG, required: true },
    BLANK,
    { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
  ] },
  { method: 'delete', path: '${e.route}/:${p}', action: '${deactName}', tokenIdentity: 'actor', fields: [
    ${keyField}, BLANK, BLANK, BLANK, BLANK,
    { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
  ] },`;
  }).join('\n');
  return `import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };

export const REF_ROUTES = [
${blocks}
];
`;
}

function testFile(e) {
  const tk = 'Z'.repeat(e.key.length);
  const bad = tk.slice(0, Math.max(1, e.key.length - 1));
  const ddlSql = e.createTable ? ddl(e).replace(/\n/g, ' ') : '';
  return `#!/bin/bash
# Generated smoke suite for the ${e.name} reference module.
set -u
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="\${DB_USER:-cobol_user}"
DB_PASS="\${DB_PASS:-cobol_pass}"
DB_NAME="\${DB_NAME:-cobol_db}"

GREEN='\\033[0;32m'; RED='\\033[0;31m'; NC='\\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "\${GREEN}PASS\${NC} $name"; passed=$((passed+1))
    else
        echo -e "\${RED}FAIL\${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}
check_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "\${GREEN}PASS\${NC} $name"; passed=$((passed+1))
    else
        echo -e "\${RED}FAIL\${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

ADM="ref_admin@test.com"
USR="ref_user@test.com"
setup() {
    q "CREATE TABLE IF NOT EXISTS reference_audit (
         id INT AUTO_INCREMENT PRIMARY KEY,
         entity VARCHAR(64) NOT NULL,
         entity_key VARCHAR(128) NOT NULL,
         action VARCHAR(32) NOT NULL,
         actor_email VARCHAR(100),
         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       ) ENGINE=InnoDB;
${ddlSql ? `       ${ddlSql}\n` : ''}       DELETE FROM ${e.table} WHERE ${e.key.column} = '${tk}';
       DELETE FROM reference_audit WHERE entity = '${e.table}';
       DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (970,'$ADM','x','Ref Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (971,'$USR','x','Ref User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}
teardown() {
    q "DELETE FROM ${e.table} WHERE ${e.key.column} = '${tk}';
       DELETE FROM reference_audit WHERE entity = '${e.table}';
       DELETE FROM audit_trail WHERE action LIKE 'REF_${e.code}_%';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  REFERENCE ${e.name} SUITE"
echo "======================================================================"
setup

check "create ${tk}" "SUCCESS|REF_CREATED" "$(run REF_${e.code}_CREATE ${tk} Z 2 1 '' "$ADM")"
check_contains "list contains created key" "${tk}" "$(run REF_${e.code}_LIST 20 0 '' '' '' "$ADM")"
check "get ${tk}" "SUCCESS|REF_GET|${tk}:Z:2:1" "$(run REF_${e.code}_GET ${tk} '' '' '' '' "$ADM")"
check "update ${tk}" "SUCCESS|REF_UPDATED" "$(run REF_${e.code}_UPDATE ${tk} ZZ 3 1 '' "$ADM")"
check "get ${tk} after update" "SUCCESS|REF_GET|${tk}:ZZ:3:1" "$(run REF_${e.code}_GET ${tk} '' '' '' '' "$ADM")"
check "deactivate ${tk}" "SUCCESS|REF_DEACTIVATED" "$(run REF_${e.code}_DEACT ${tk} '' '' '' '' "$ADM")"
check "get ${tk} after deactivate" "SUCCESS|REF_GET|${tk}:ZZ:3:0" "$(run REF_${e.code}_GET ${tk} '' '' '' '' "$ADM")"
check "duplicate create rejected" "ERROR|DUPLICATE" "$(run REF_${e.code}_CREATE ${tk} Z 2 1 '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run REF_${e.code}_LIST 20 0 '' '' '' "$USR")"
check "bad key rejected" "ERROR|INVALID_INPUT" "$(run REF_${e.code}_CREATE ${bad} Z 2 1 '' "$ADM")"
check "audit rows recorded" "3" "$(q "SELECT COUNT(*) FROM reference_audit WHERE entity='${e.table}' AND entity_key='${tk}';")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
`;
}

write('cobol/src/ref_core.cob', cobol());
write('database/migrations/0047_ref_entities.sql', migration());
write('middleware/src/routes/ref.js', routes());
for (const e of entities) {
  write(`tests/lab/test_ref_${e.name}.sh`, testFile(e));
  fs.chmodSync(path.join(root, `tests/lab/test_ref_${e.name}.sh`), 0o755);
}

// Replace the generated dispatch block in main_logic.cob.
const mainPath = path.join(root, 'cobol/src/main_logic.cob');
let main = fs.readFileSync(mainPath, 'utf8');
const begin = '            *> BEGIN GENERATED REF DISPATCH';
const end = '            *> END GENERATED REF DISPATCH';
const b = main.indexOf(begin);
const en = main.indexOf(end);
if (b < 0 || en < 0 || en < b) {
  console.error('main_logic.cob is missing the generated dispatch markers');
  process.exit(1);
}
main = main.slice(0, b + begin.length) + '\n' + dispatchBlock() + main.slice(en);
fs.writeFileSync(mainPath, main);

console.log(`generated ${entities.length} reference entities`);
console.log(`  cobol/src/ref_core.cob`);
console.log(`  database/migrations/0047_ref_entities.sql`);
console.log(`  middleware/src/routes/ref.js`);
console.log(`  tests/lab/test_ref_*.sh`);
