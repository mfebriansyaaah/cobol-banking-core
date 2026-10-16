#include <mysql/mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* 
 * COBOL SQL Bridge - Global Buffer Version
 * Uses explicit setter/getter to avoid stack corruption.
 */

char G_QUERY[1024] = {0};
char G_RESULT[16384] = {0};

/* Persistent connection, held only for the span of an explicit transaction. */
static MYSQL *G_CONN = NULL;
/* Keep-alive connection reused across calls (pinged, reconnected if stale). */
static MYSQL *G_POOL = NULL;

/* Read a connection setting from the environment, falling back to the
 * development default. Keeps credentials out of the source and lets each
 * deployment (and the gateway that spawns the binary) configure them. */
static const char *env_or(const char *name, const char *fallback) {
    const char *v = getenv(name);
    return (v && v[0] != '\0') ? v : fallback;
}

static MYSQL *bridge_connect(void) {
    /* Reuse the keep-alive connection when it is still alive; if the server
     * dropped it (idle timeout, restart, kill), reconnect once. */
    if (G_POOL != NULL) {
        if (mysql_ping(G_POOL) == 0) return G_POOL;
        mysql_close(G_POOL);
        G_POOL = NULL;
    }
    MYSQL *c = mysql_init(NULL);
    if (c == NULL) return NULL;
    const char *host = env_or("DB_HOST", "localhost");
    const char *user = env_or("DB_USER", "cobol_user");
    const char *pass = env_or("DB_PASS", "cobol_pass");
    const char *dbname = env_or("DB_NAME", "cobol_db");
    unsigned int port = (unsigned int)atoi(env_or("DB_PORT", "3306"));
    if (mysql_real_connect(c, host, user, pass, dbname, port, NULL, 0) == NULL) {
        mysql_close(c);
        return NULL;
    }
    G_POOL = c;
    return c;
}

void sanitize_string(char *str) {
    if (!str) return;
    int i = 0;
    while (str[i]) {
        if (!isprint((unsigned char)str[i]) && str[i] != '\n' && str[i] != '\r' && str[i] != '\t') {
            str[i] = ' ';
        }
        i++;
    }
}

void trim_trailing_spaces(char *str) {
    if (!str) return;
    int len = strlen(str);
    while (len > 0 && isspace((unsigned char)str[len - 1])) {
        str[len - 1] = '\0';
        len--;
    }
}

void trim_leading_spaces(char *str) {
    if (!str) return;
    int start = 0;
    while (str[start] && isspace((unsigned char)str[start])) {
        start++;
    }
    if (start > 0) {
        memmove(str, str + start, strlen(str + start) + 1);
    }
}

void SET_QUERY(char *query) {
    if (!query) return;
    memset(G_QUERY, 0, sizeof(G_QUERY));
    strncpy(G_QUERY, query, 511);
    G_QUERY[511] = '\0';
    trim_trailing_spaces(G_QUERY);
}

void GET_RESULT(char *result) {
    if (!result) return;
    size_t len = strlen(G_RESULT);
    if (len > 16383) len = 16383;
    memset(result, ' ', 16383);
    memcpy(result, G_RESULT, len);
}

void SQL_EXECUTE() {
    MYSQL *conn;
    MYSQL_RES *res;
    MYSQL_ROW row;
    int own_conn = 0;

    if (G_CONN != NULL) {
        conn = G_CONN;
    } else {
        conn = bridge_connect();
        own_conn = 1;
        if (conn == NULL) {
            strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383);
            return;
        }
    }

    /* Length only: G_QUERY on this path holds concatenated literals (emails),
     * so the text itself must never reach the logs. */
    fprintf(stderr, "[SQL_BRIDGE] Executing query (%zu bytes)\\n", strlen(G_QUERY));

    if (mysql_query(conn, G_QUERY)) {
        snprintf(G_RESULT, 16383, "ERROR|QUERY_FAILED|%d", mysql_errno(conn));
        /* pooled: connection kept for reuse */
        return;
    }

    res = mysql_store_result(conn);
    if (res == NULL) {
        long affected = mysql_affected_rows(conn);
        snprintf(G_RESULT, 16383, "SUCCESS|AFFECTED_%ld", affected);
    } else {
        row = mysql_fetch_row(res);
        if (row) {
            G_RESULT[0] = '\0';
            unsigned int num_fields = mysql_num_fields(res);
            for (unsigned int i = 0; i < num_fields; i++) {
                if (row[i]) {
                    char temp[256];
                    strncpy(temp, row[i], 255);
                    temp[255] = '\0';
                    sanitize_string(temp);
                    trim_trailing_spaces(temp);
                    strncat(G_RESULT, temp, 16383 - strlen(G_RESULT) - 1);
                } else {
                    strncat(G_RESULT, "NULL", 16383 - strlen(G_RESULT) - 1);
                }
                if (i < num_fields - 1) {
                    strncat(G_RESULT, "|", 16383 - strlen(G_RESULT) - 1);
                }
            }
        } else {
            strncpy(G_RESULT, "ERROR|NO_DATA", 16383);
        }
        mysql_free_result(res);
    }

    /* pooled: connection kept for reuse */
}

/* --- Parameter escaping --------------------------------------------------
 * Escape one COBOL-provided value for safe embedding in a SQL literal.
 * The input's trailing spaces are trimmed; the result is written to the
 * caller's buffer and padded with spaces (never NUL) so COBOL stays valid.
 * ------------------------------------------------------------------------ */

void SQL_ESCAPE(char *in, char *out, int outmax) {
    if (!out || outmax <= 0) return;
    memset(out, ' ', (size_t)outmax);
    if (!in) return;

    char trimmed[1024];
    strncpy(trimmed, in, 100);
    trimmed[100] = '\0';
    trim_trailing_spaces(trimmed);
    size_t len = strlen(trimmed);
    if (len == 0) return;

    char escaped[2048];
    MYSQL *conn = G_CONN;
    int own = 0;
    if (conn == NULL) {
        conn = bridge_connect();
        own = 1;
    }
    size_t elen;
    if (conn != NULL) {
        elen = mysql_real_escape_string(conn, escaped, trimmed, len);
        /* pooled: connection kept for reuse */
    } else {
        // No connection available: fall back to a copy (callers still reject
        // protocol-breaking characters).
        memcpy(escaped, trimmed, len);
        elen = len;
    }
    if (elen > (size_t)outmax) elen = (size_t)outmax;
    memcpy(out, escaped, elen);
}

/* --- Multi-row execute ---------------------------------------------------
 * Like SQL_EXECUTE but concatenates EVERY row: fields joined by '|', rows
 * joined by ';'. Lets a COBOL action read a list without GROUP_CONCAT hacks.
 * ------------------------------------------------------------------------ */

void SQL_EXECUTE_ROWS() {
    MYSQL *conn;
    MYSQL_RES *res;
    MYSQL_ROW row;
    int own_conn = 0;

    if (G_CONN != NULL) {
        conn = G_CONN;
    } else {
        conn = bridge_connect();
        own_conn = 1;
        if (conn == NULL) {
            strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383);
            return;
        }
    }

    fprintf(stderr, "[SQL_BRIDGE] Executing rows query (%zu bytes)\\n", strlen(G_QUERY));

    if (mysql_query(conn, G_QUERY)) {
        snprintf(G_RESULT, 16383, "ERROR|QUERY_FAILED|%d", mysql_errno(conn));
        /* pooled: connection kept for reuse */
        return;
    }

    res = mysql_store_result(conn);
    if (res == NULL) {
        long affected = mysql_affected_rows(conn);
        snprintf(G_RESULT, 16383, "SUCCESS|AFFECTED_%ld", affected);
        /* pooled: connection kept for reuse */
        return;
    }

    G_RESULT[0] = '\0';
    unsigned int num_fields = mysql_num_fields(res);
    int first_row = 1;
    while ((row = mysql_fetch_row(res)) != NULL) {
        if (!first_row) {
            strncat(G_RESULT, ";", 16383 - strlen(G_RESULT) - 1);
        }
        first_row = 0;
        for (unsigned int i = 0; i < num_fields; i++) {
            if (row[i]) {
                char temp[256];
                strncpy(temp, row[i], 255);
                temp[255] = '\0';
                sanitize_string(temp);
                trim_trailing_spaces(temp);
                strncat(G_RESULT, temp, 16383 - strlen(G_RESULT) - 1);
            } else {
                strncat(G_RESULT, "NULL", 16383 - strlen(G_RESULT) - 1);
            }
            if (i < num_fields - 1) {
                strncat(G_RESULT, "|", 16383 - strlen(G_RESULT) - 1);
            }
        }
    }
    if (first_row) {
        strncpy(G_RESULT, "ERROR|NO_DATA", 16383);
    }
    mysql_free_result(res);
    /* pooled: connection kept for reuse */
}

/* --- Transaction control -------------------------------------------------
 * The plain SQL_EXECUTE has no transaction because it connects and
 * disconnects per call. BEGIN opens a persistent connection that the
 * following SQL_EXECUTE calls share until COMMIT/ROLLBACK closes it.
 * ------------------------------------------------------------------------ */

void SQL_BEGIN() {
    if (G_CONN != NULL) {
        G_CONN = NULL;   /* keep the pooled connection */
    }
    G_CONN = bridge_connect();
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383);
        return;
    }
    if (mysql_query(G_CONN, "START TRANSACTION")) {
        strncpy(G_RESULT, "ERROR|BEGIN_FAILED", 16383);
        G_CONN = NULL;
        return;
    }
    strncpy(G_RESULT, "SUCCESS|BEGIN", 16383);
}

void SQL_COMMIT() {
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|NO_TRANSACTION", 16383);
        return;
    }
    if (mysql_query(G_CONN, "COMMIT")) {
        strncpy(G_RESULT, "ERROR|COMMIT_FAILED", 16383);
    } else {
        strncpy(G_RESULT, "SUCCESS|COMMIT", 16383);
    }
    G_CONN = NULL;   /* pooled connection is kept for reuse */
}

void SQL_ROLLBACK() {
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|NO_TRANSACTION", 16383);
        return;
    }
    if (mysql_query(G_CONN, "ROLLBACK")) {
        strncpy(G_RESULT, "ERROR|ROLLBACK_FAILED", 16383);
    } else {
        strncpy(G_RESULT, "SUCCESS|ROLLBACK", 16383);
    }
    G_CONN = NULL;   /* pooled connection is kept for reuse */
}

/* --- Prepared statement execution ---------------------------------------
 * Prepare a template with '?' placeholders and bind up to six string
 * parameters (values are sent to the server, never concatenated). Single-row
 * results are concatenated like SQL_EXECUTE.
 * ------------------------------------------------------------------------ */

void SQL_PREPARE_EXEC(char *sql, int nparams,
                      char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    if (!sql) return;

    char query[1024];
    strncpy(query, sql, 1023);
    query[1023] = '\0';
    trim_trailing_spaces(query);
    if (query[0] == '\0') return;

    MYSQL *conn = G_CONN;
    int own_conn = 0;
    if (conn == NULL) {
        conn = bridge_connect();
        own_conn = 1;
        if (conn == NULL) { strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383); return; }
    }

    MYSQL_STMT *st = mysql_stmt_init(conn);
    if (st == NULL) {
        strncpy(G_RESULT, "ERROR|STMT_INIT_FAILED", 16383);
        /* pooled: connection kept for reuse */
        return;
    }
    if (mysql_stmt_prepare(st, query, (unsigned long)strlen(query))) {
        snprintf(G_RESULT, 16383, "ERROR|PREPARE_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    char *src[6] = { p1, p2, p3, p4, p5, p6 };
    static char bufs[6][512];
    static unsigned long lens[6];
    MYSQL_BIND bind[6];
    memset(bind, 0, sizeof(bind));

    int n = nparams;
    if (n < 0) n = 0;
    if (n > 6) n = 6;

    for (int i = 0; i < n; i++) {
        memset(bufs[i], 0, sizeof(bufs[i]));
        if (src[i]) { strncpy(bufs[i], src[i], 256); bufs[i][256] = '\0'; }
        trim_trailing_spaces(bufs[i]);
        lens[i] = (unsigned long)strlen(bufs[i]);
        bind[i].buffer_type = MYSQL_TYPE_STRING;
        bind[i].buffer = bufs[i];
        bind[i].buffer_length = 511;
        bind[i].length = &lens[i];
    }
    if (n > 0 && mysql_stmt_bind_param(st, bind)) {
        strncpy(G_RESULT, "ERROR|BIND_FAILED", 16383);
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    if (mysql_stmt_execute(st)) {
        snprintf(G_RESULT, 16383, "ERROR|EXEC_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    MYSQL_RES *meta = mysql_stmt_result_metadata(st);
    if (meta == NULL) {
        long affected = (long)mysql_stmt_affected_rows(st);
        snprintf(G_RESULT, 16383, "SUCCESS|AFFECTED_%ld", affected);
    } else {
        unsigned int nf = mysql_num_fields(meta);
        MYSQL_FIELD *fields = mysql_fetch_fields(meta);
        static char rbuf[32][512];
        static unsigned long rlen[32];
        MYSQL_BIND rb[32];
        memset(rb, 0, sizeof(rb));
        unsigned int cols = nf < 32 ? nf : 32;
        for (unsigned int i = 0; i < cols; i++) {
            memset(rbuf[i], 0, sizeof(rbuf[i]));
            rlen[i] = 0;
            rb[i].buffer_type = MYSQL_TYPE_STRING;
            rb[i].buffer = rbuf[i];
            rb[i].buffer_length = 511;
            rb[i].length = &rlen[i];
        }
        if (mysql_stmt_bind_result(st, rb) || mysql_stmt_store_result(st)) {
            strncpy(G_RESULT, "ERROR|RESULT_BIND_FAILED", 16383);
            mysql_free_result(meta);
            mysql_stmt_close(st);
            /* pooled: connection kept for reuse */
            return;
        }
        int rc = mysql_stmt_fetch(st);
        if (rc == 0 || rc == MYSQL_DATA_TRUNCATED) {
            G_RESULT[0] = '\0';
            for (unsigned int i = 0; i < cols; i++) {
                char temp[512];
                unsigned long l = rlen[i] < 511 ? rlen[i] : 511;
                memcpy(temp, rbuf[i], l);
                temp[l] = '\0';
                sanitize_string(temp);
                trim_trailing_spaces(temp);
                strncat(G_RESULT, temp, 16383 - strlen(G_RESULT) - 1);
                if (i < cols - 1) strncat(G_RESULT, "|", 16383 - strlen(G_RESULT) - 1);
            }
        } else {
            strncpy(G_RESULT, "ERROR|NO_DATA", 16383);
        }
        mysql_free_result(meta);
    }

    mysql_stmt_close(st);
    /* pooled: connection kept for reuse */
}

/* --- Prepared execute with up to seven bound parameters -----------------
 * Same as SQL_PREPARE_EXEC but with one extra slot, for the CREDIT ledger
 * insert which binds the rate twice (multiply + snapshot) plus the sender.
 * ------------------------------------------------------------------------ */

void SQL_PREPARE_EXEC7(char *sql, int nparams,
                       char *p1, char *p2, char *p3, char *p4, char *p5, char *p6, char *p7) {
    if (!sql) return;

    char query[1024];
    strncpy(query, sql, 1023);
    query[1023] = '\0';
    trim_trailing_spaces(query);
    if (query[0] == '\0') return;

    MYSQL *conn = G_CONN;
    if (conn == NULL) {
        conn = bridge_connect();
        if (conn == NULL) { strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383); return; }
    }

    MYSQL_STMT *st = mysql_stmt_init(conn);
    if (st == NULL) {
        strncpy(G_RESULT, "ERROR|STMT_INIT_FAILED", 16383);
        return;
    }
    if (mysql_stmt_prepare(st, query, (unsigned long)strlen(query))) {
        snprintf(G_RESULT, 16383, "ERROR|PREPARE_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        return;
    }

    char *src[7] = { p1, p2, p3, p4, p5, p6, p7 };
    static char bufs[7][512];
    static unsigned long lens[7];
    MYSQL_BIND bind[7];
    memset(bind, 0, sizeof(bind));

    int n = nparams;
    if (n < 0) n = 0;
    if (n > 7) n = 7;

    for (int i = 0; i < n; i++) {
        memset(bufs[i], 0, sizeof(bufs[i]));
        if (src[i]) { strncpy(bufs[i], src[i], 256); bufs[i][256] = '\0'; }
        trim_trailing_spaces(bufs[i]);
        lens[i] = (unsigned long)strlen(bufs[i]);
        bind[i].buffer_type = MYSQL_TYPE_STRING;
        bind[i].buffer = bufs[i];
        bind[i].buffer_length = 511;
        bind[i].length = &lens[i];
    }
    if (n > 0 && mysql_stmt_bind_param(st, bind)) {
        strncpy(G_RESULT, "ERROR|BIND_FAILED", 16383);
        mysql_stmt_close(st);
        return;
    }

    if (mysql_stmt_execute(st)) {
        snprintf(G_RESULT, 16383, "ERROR|EXEC_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        return;
    }

    MYSQL_RES *meta = mysql_stmt_result_metadata(st);
    if (meta == NULL) {
        long affected = (long)mysql_stmt_affected_rows(st);
        snprintf(G_RESULT, 16383, "SUCCESS|AFFECTED_%ld", affected);
    } else {
        unsigned int nf = mysql_num_fields(meta);
        static char rbuf[32][512];
        static unsigned long rlen[32];
        MYSQL_BIND rb[32];
        memset(rb, 0, sizeof(rb));
        unsigned int cols = nf < 32 ? nf : 32;
        for (unsigned int i = 0; i < cols; i++) {
            memset(rbuf[i], 0, sizeof(rbuf[i]));
            rlen[i] = 0;
            rb[i].buffer_type = MYSQL_TYPE_STRING;
            rb[i].buffer = rbuf[i];
            rb[i].buffer_length = 511;
            rb[i].length = &rlen[i];
        }
        if (mysql_stmt_bind_result(st, rb) || mysql_stmt_store_result(st)) {
            strncpy(G_RESULT, "ERROR|RESULT_BIND_FAILED", 16383);
            mysql_free_result(meta);
            mysql_stmt_close(st);
            return;
        }
        int rc = mysql_stmt_fetch(st);
        if (rc == 0 || rc == MYSQL_DATA_TRUNCATED) {
            G_RESULT[0] = '\0';
            for (unsigned int i = 0; i < cols; i++) {
                char temp[512];
                unsigned long l = rlen[i] < 511 ? rlen[i] : 511;
                memcpy(temp, rbuf[i], l);
                temp[l] = '\0';
                sanitize_string(temp);
                trim_trailing_spaces(temp);
                strncat(G_RESULT, temp, 16383 - strlen(G_RESULT) - 1);
                if (i < cols - 1) strncat(G_RESULT, "|", 16383 - strlen(G_RESULT) - 1);
            }
        } else {
            strncpy(G_RESULT, "ERROR|NO_DATA", 16383);
        }
        mysql_free_result(meta);
    }

    mysql_stmt_close(st);
}

/* --- Prepared execute without reading rows ------------------------------
 * Binds parameters and runs the statement, but does not fetch/bind a result
 * set. Used for a locking `SELECT ... FOR UPDATE` whose rows are not needed;
 * reading them via mysql_stmt_store_result makes MariaDB raise ER_CHECKREAD
 * (1020) under contention, even though the lock itself succeeded.
 * ------------------------------------------------------------------------ */

void SQL_PREPARE_EXEC_LOCK(char *sql, int nparams,
                           char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    if (!sql) return;

    char query[1024];
    strncpy(query, sql, 1023);
    query[1023] = '\0';
    trim_trailing_spaces(query);
    if (query[0] == '\0') return;

    MYSQL *conn = G_CONN;
    int own_conn = 0;
    if (conn == NULL) {
        conn = bridge_connect();
        own_conn = 1;
        if (conn == NULL) { strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383); return; }
    }

    MYSQL_STMT *st = mysql_stmt_init(conn);
    if (st == NULL) {
        strncpy(G_RESULT, "ERROR|STMT_INIT_FAILED", 16383);
        /* pooled: connection kept for reuse */
        return;
    }
    if (mysql_stmt_prepare(st, query, (unsigned long)strlen(query))) {
        snprintf(G_RESULT, 16383, "ERROR|PREPARE_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    char *src[6] = { p1, p2, p3, p4, p5, p6 };
    static char bufs[6][512];
    static unsigned long lens[6];
    MYSQL_BIND bind[6];
    memset(bind, 0, sizeof(bind));

    int n = nparams;
    if (n < 0) n = 0;
    if (n > 6) n = 6;

    for (int i = 0; i < n; i++) {
        memset(bufs[i], 0, sizeof(bufs[i]));
        if (src[i]) { strncpy(bufs[i], src[i], 256); bufs[i][256] = '\0'; }
        trim_trailing_spaces(bufs[i]);
        lens[i] = (unsigned long)strlen(bufs[i]);
        bind[i].buffer_type = MYSQL_TYPE_STRING;
        bind[i].buffer = bufs[i];
        bind[i].buffer_length = 511;
        bind[i].length = &lens[i];
    }
    if (n > 0 && mysql_stmt_bind_param(st, bind)) {
        strncpy(G_RESULT, "ERROR|BIND_FAILED", 16383);
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    if (mysql_stmt_execute(st)) {
        snprintf(G_RESULT, 16383, "ERROR|EXEC_FAILED|%d", mysql_errno(conn));
    } else {
        strncpy(G_RESULT, "SUCCESS|LOCKED", 16383);
    }

    mysql_stmt_close(st);
    /* pooled: connection kept for reuse */
}

/* --- Prepared multi-row execute -----------------------------------------
 * Like SQL_PREPARE_EXEC (bound parameters) but concatenates EVERY row:
 * fields joined by '|', rows joined by ';'. Used for paged lists whose
 * LIMIT/OFFSET are supplied by the caller.
 * ------------------------------------------------------------------------ */

void SQL_PREPARE_EXEC_ROWS(char *sql, int nparams,
                           char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    if (!sql) return;

    char query[1024];
    strncpy(query, sql, 1023);
    query[1023] = '\0';
    trim_trailing_spaces(query);
    if (query[0] == '\0') return;

    MYSQL *conn = G_CONN;
    int own_conn = 0;
    if (conn == NULL) {
        conn = bridge_connect();
        own_conn = 1;
        if (conn == NULL) { strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 16383); return; }
    }

    MYSQL_STMT *st = mysql_stmt_init(conn);
    if (st == NULL) {
        strncpy(G_RESULT, "ERROR|STMT_INIT_FAILED", 16383);
        /* pooled: connection kept for reuse */
        return;
    }
    if (mysql_stmt_prepare(st, query, (unsigned long)strlen(query))) {
        snprintf(G_RESULT, 16383, "ERROR|PREPARE_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    char *src[6] = { p1, p2, p3, p4, p5, p6 };
    static char bufs[6][512];
    static unsigned long lens[6];
    MYSQL_BIND bind[6];
    memset(bind, 0, sizeof(bind));

    int n = nparams;
    if (n < 0) n = 0;
    if (n > 6) n = 6;

    for (int i = 0; i < n; i++) {
        memset(bufs[i], 0, sizeof(bufs[i]));
        if (src[i]) { strncpy(bufs[i], src[i], 256); bufs[i][256] = '\0'; }
        trim_trailing_spaces(bufs[i]);
        lens[i] = (unsigned long)strlen(bufs[i]);
        bind[i].buffer_type = MYSQL_TYPE_STRING;
        bind[i].buffer = bufs[i];
        bind[i].buffer_length = 511;
        bind[i].length = &lens[i];
    }
    if (n > 0 && mysql_stmt_bind_param(st, bind)) {
        strncpy(G_RESULT, "ERROR|BIND_FAILED", 16383);
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    if (mysql_stmt_execute(st)) {
        snprintf(G_RESULT, 16383, "ERROR|EXEC_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    MYSQL_RES *meta = mysql_stmt_result_metadata(st);
    if (meta == NULL) {
        long affected = (long)mysql_stmt_affected_rows(st);
        snprintf(G_RESULT, 16383, "SUCCESS|AFFECTED_%ld", affected);
    } else {
        unsigned int nf = mysql_num_fields(meta);
        static char rbuf[32][512];
        static unsigned long rlen[32];
        MYSQL_BIND rb[32];
        memset(rb, 0, sizeof(rb));
        unsigned int cols = nf < 32 ? nf : 32;
        for (unsigned int i = 0; i < cols; i++) {
            memset(rbuf[i], 0, sizeof(rbuf[i]));
            rlen[i] = 0;
            rb[i].buffer_type = MYSQL_TYPE_STRING;
            rb[i].buffer = rbuf[i];
            rb[i].buffer_length = 511;
            rb[i].length = &rlen[i];
        }
        if (mysql_stmt_bind_result(st, rb) || mysql_stmt_store_result(st)) {
            strncpy(G_RESULT, "ERROR|RESULT_BIND_FAILED", 16383);
            mysql_free_result(meta);
            mysql_stmt_close(st);
            /* pooled: connection kept for reuse */
            return;
        }
        G_RESULT[0] = '\0';
        int first_row = 1;
        int rc;
        while ((rc = mysql_stmt_fetch(st)) == 0 || rc == MYSQL_DATA_TRUNCATED) {
            if (!first_row) strncat(G_RESULT, ";", 16383 - strlen(G_RESULT) - 1);
            first_row = 0;
            for (unsigned int i = 0; i < cols; i++) {
                char temp[512];
                unsigned long l = rlen[i] < 511 ? rlen[i] : 511;
                memcpy(temp, rbuf[i], l);
                temp[l] = '\0';
                sanitize_string(temp);
                trim_trailing_spaces(temp);
                strncat(G_RESULT, temp, 16383 - strlen(G_RESULT) - 1);
                if (i < cols - 1) strncat(G_RESULT, "|", 16383 - strlen(G_RESULT) - 1);
            }
        }
        if (first_row) {
            strncpy(G_RESULT, "ERROR|NO_DATA", 16383);
        }
        mysql_free_result(meta);
    }

    mysql_stmt_close(st);
    /* pooled: connection kept for reuse */
}
