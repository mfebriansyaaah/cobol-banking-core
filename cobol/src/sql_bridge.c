#include <mysql/mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* 
 * COBOL SQL Bridge - Global Buffer Version
 * Uses explicit setter/getter to avoid stack corruption.
 */

__thread char G_QUERY[1024] = {0};
__thread char G_RESULT[16384] = {0};

/* Persistent connection, held only for the span of an explicit transaction. */
static __thread MYSQL *G_CONN = NULL;
/* Keep-alive connection reused across calls (pinged, reconnected if stale). */
static __thread MYSQL *G_POOL = NULL;

/* Read a connection setting from the environment, falling back to the
 * development default. Keeps credentials out of the source and lets each
 * deployment (and the gateway that spawns the binary) configure them. */
static const char *env_or(const char *name, const char *fallback) {
    const char *v = getenv(name);
    return (v && v[0] != '\0') ? v : fallback;
}

/* Debug logging is opt-in via SQL_BRIDGE_DEBUG=1. Per-query and per-row
 * stderr noise stays out of production logs; abnormal conditions (a leaked
 * transaction rollback) are always reported. */
static int bridge_debug(void) {
    static int checked = 0;
    static int enabled = 0;
    if (!checked) {
        const char *v = getenv("SQL_BRIDGE_DEBUG");
        enabled = (v && v[0] != '\0' && strcmp(v, "0") != 0);
        checked = 1;
    }
    return enabled;
}

/* True when the process is in production but the database credentials are
 * still the development defaults (or unset). Production must set them
 * explicitly; the gateway refuses to start on the same condition, and this
 * is the fail-closed backstop for a directly-invoked binary. */
static int db_config_insecure(void) {
    const char *env = getenv("NODE_ENV");
    if (env == NULL || strcmp(env, "production") != 0) return 0;
    const char *user = getenv("DB_USER");
    const char *pass = getenv("DB_PASS");
    int dev_user = (user == NULL || user[0] == '\0' || strcmp(user, "cobol_user") == 0);
    int dev_pass = (pass == NULL || pass[0] == '\0' || strcmp(pass, "cobol_pass") == 0);
    return dev_user || dev_pass;
}

/* Report why a connection could not be established, distinguishing an
 * insecure configuration from an unreachable database. */
static void set_connect_error(int insecure) {
    strncpy(G_RESULT, insecure ? "ERROR|DB_CONFIG_INSECURE" : "ERROR|DB_CONN_FAILED", 16383);
}

static MYSQL *bridge_connect(int *insecure) {
    if (insecure != NULL) *insecure = 0;
    /* Fail closed before touching the network: a production process must not
     * silently connect with the development credentials baked in below. */
    if (db_config_insecure()) {
        if (insecure != NULL) *insecure = 1;
        return NULL;
    }
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
    /* Fail-closed isolation: READ COMMITTED removes the stale snapshot that
     * a REPEATABLE-READ transaction keeps after a locking SELECT, so the
     * post-lock re-reads (status, currency, available balance, limits) see
     * the committed state the lock actually protects. */
    mysql_query(c, "SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED");
    G_POOL = c;
    return c;
}

void sanitize_string(char *str) {
    if (!str) return;
    int i = 0;
    while (str[i]) {
        /* ADR-0006: \n \r \t corrupt the line-delimited --serve framing
         * (one COBOL result per stdout line; pool.js maps lines FIFO).
         * Replace them with spaces so DB content can never split framing. */
        if (!isprint((unsigned char)str[i]) || str[i] == '\n' || str[i] == '\r' || str[i] == '\t') {
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

void SET_QUERY(char *query) {
    if (!query) return;
    memset(G_QUERY, 0, sizeof(G_QUERY));
    /* WS-QUERY is PIC X(512) space-padded, not NUL-terminated: copy a bounded
     * prefix (original 511 semantics) so we never overread into adjacent
     * WORKING-STORAGE. Longer WS-PREP-SQL goes via prepared_exec, not here. */
    strncpy(G_QUERY, query, 511);
    G_QUERY[511] = '\0';
    trim_trailing_spaces(G_QUERY);
}

void GET_RESULT(char *result) {
    if (!result) return;
    size_t len = strlen(G_RESULT);
    if (bridge_debug()) fprintf(stderr, "GET_RESULT len=%zu\n", len);
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
        int insecure = 0;
        conn = bridge_connect(&insecure);
        own_conn = 1;
        if (conn == NULL) {
            set_connect_error(insecure);
            return;
        }
    }

    /* Length only: G_QUERY on this path holds concatenated literals (emails),
     * so the text itself must never reach the logs. */
    if (bridge_debug()) fprintf(stderr, "[SQL_BRIDGE] Executing query (%zu bytes)\\n", strlen(G_QUERY));

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
        conn = bridge_connect(NULL);
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

/* --- Transaction control -------------------------------------------------
 * The plain SQL_EXECUTE has no transaction because it connects and
 * disconnects per call. BEGIN opens a persistent connection that the
 * following SQL_EXECUTE calls share until COMMIT/ROLLBACK closes it.
 * ------------------------------------------------------------------------ */

void SQL_BEGIN() {
    if (G_CONN != NULL) {
        /* A previous transaction is still open (missed COMMIT/ROLLBACK):
         * roll it back rather than abandoning it — the START TRANSACTION
         * below would otherwise implicitly commit its partial work. The
         * pooled connection itself is kept for reuse. */
        mysql_query(G_CONN, "ROLLBACK");
        fprintf(stderr, "[SQL_BRIDGE] Rolled back a leaked transaction\\n");
        G_CONN = NULL;
    }
    int insecure = 0;
    G_CONN = bridge_connect(&insecure);
    if (G_CONN == NULL) {
        set_connect_error(insecure);
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
        /* Keep the failure attributable, then roll back the still-open
         * transaction before releasing the connection so row locks do not
         * leak into the next request on the pooled connection. */
        strncpy(G_RESULT, "ERROR|COMMIT_FAILED", 16383);
        mysql_query(G_CONN, "ROLLBACK");
        G_CONN = NULL;
        return;
    }
    strncpy(G_RESULT, "SUCCESS|COMMIT", 16383);
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
/* --- Unified prepared execution (PR-060) ----------------------------------
 * One core, thin entry points. Modes:
 *   EXEC_ONE  — first row only (fields joined by '|'), else ERROR|NO_DATA.
 *   EXEC_ROWS — every row (fields '|', rows ';'), else ERROR|NO_DATA.
 *   EXEC_LOCK — no fetch at all (locking SELECT); SUCCESS|LOCKED.
 * Parameter capacity is 7 for every mode (EXEC7 was EXEC_ONE with 7 slots).
 * Every error string is byte-identical to the pre-unification variants.
 * ------------------------------------------------------------------------ */

enum exec_mode { EXEC_ONE, EXEC_ROWS, EXEC_LOCK };

#define RES_CAP 16383
#define MAX_COLS 32
#define ROW_CAP 2000

/* Set when output would exceed the 16KB result buffer (PR-061): the caller
 * gets ERROR|RESULT_TRUNCATED instead of a silently cut response. */
static int g_truncated = 0;

/* Append one sanitized field value (already length-capped by the caller). */
static void append_field(const char *text) {
    char temp[512];
    strncpy(temp, text ? text : "", 511);
    temp[511] = '\0';
    sanitize_string(temp);
    trim_trailing_spaces(temp);
    if (strlen(G_RESULT) + strlen(temp) + 1 >= RES_CAP) {
        g_truncated = 1;
        return;
    }
    strncat(G_RESULT, temp, RES_CAP - strlen(G_RESULT) - 1);
}

static void append_sep(const char *sep) {
    if (strlen(G_RESULT) + strlen(sep) >= RES_CAP) {
        g_truncated = 1;
        return;
    }
    strncat(G_RESULT, sep, RES_CAP - strlen(G_RESULT) - 1);
}

/* Bind string column buffers for fetching (up to MAX_COLS columns). */
static int bind_columns(MYSQL_STMT *st, char rbuf[MAX_COLS][512], unsigned long rlen[MAX_COLS],
                        MYSQL_BIND rb[MAX_COLS], unsigned int *cols) {
    MYSQL_RES *meta = mysql_stmt_result_metadata(st);
    if (meta == NULL) return 0;
    unsigned int nf = mysql_num_fields(meta);
    *cols = nf < MAX_COLS ? nf : MAX_COLS;
    for (unsigned int i = 0; i < *cols; i++) {
        memset(rbuf[i], 0, sizeof(rbuf[i]));
        rlen[i] = 0;
        rb[i].buffer_type = MYSQL_TYPE_STRING;
        rb[i].buffer = rbuf[i];
        rb[i].buffer_length = 511;
        rb[i].length = &rlen[i];
    }
    if (mysql_stmt_bind_result(st, rb) || mysql_stmt_store_result(st)) {
        strncpy(G_RESULT, "ERROR|RESULT_BIND_FAILED", RES_CAP);
        mysql_free_result(meta);
        return -1;
    }
    mysql_free_result(meta);
    return 1;
}

/* Copy one fetched column into a NUL-terminated scratch field. */
static void column_text(char out[512], const char *rbuf, unsigned long rlen) {
    unsigned long l = rlen < 511 ? rlen : 511;
    memcpy(out, rbuf, l);
    out[l] = '\0';
}

static void fetch_one(MYSQL_STMT *st) {
    char rbuf[MAX_COLS][512];
    unsigned long rlen[MAX_COLS];
    MYSQL_BIND rb[MAX_COLS];
    unsigned int cols = 0;
    memset(rb, 0, sizeof(rb));
    int has = bind_columns(st, rbuf, rlen, rb, &cols);
    if (has < 0) return;
    if (has == 0) {
        long affected = (long)mysql_stmt_affected_rows(st);
        snprintf(G_RESULT, RES_CAP, "SUCCESS|AFFECTED_%ld", affected);
        return;
    }
    int rc = mysql_stmt_fetch(st);
    if (rc == 0 || rc == MYSQL_DATA_TRUNCATED) {
        char temp[512];
        G_RESULT[0] = '\0';
        for (unsigned int i = 0; i < cols; i++) {
            column_text(temp, rbuf[i], rlen[i]);
            append_field(temp);
            if (i < cols - 1) append_sep("|");
        }
        if (g_truncated) strncpy(G_RESULT, "ERROR|RESULT_TRUNCATED", RES_CAP);
    } else if (rc == MYSQL_NO_DATA) {
        strncpy(G_RESULT, "ERROR|NO_DATA", RES_CAP);
    } else {
        /* ADR-0006: real fetch errors must not masquerade as NO_DATA. */
        snprintf(G_RESULT, RES_CAP, "ERROR|EXEC_FAILED|%d", mysql_stmt_errno(st));
    }
}

static void fetch_all(MYSQL_STMT *st) {
    char rbuf[MAX_COLS][512];
    unsigned long rlen[MAX_COLS];
    MYSQL_BIND rb[MAX_COLS];
    unsigned int cols = 0;
    memset(rb, 0, sizeof(rb));
    int has = bind_columns(st, rbuf, rlen, rb, &cols);
    if (has < 0) return;
    if (has == 0) {
        long affected = (long)mysql_stmt_affected_rows(st);
        snprintf(G_RESULT, RES_CAP, "SUCCESS|AFFECTED_%ld", affected);
        return;
    }
    char temp[512];
    G_RESULT[0] = '\0';
    int first_row = 1;
    int rc;
    int rowcount = 0;
    int fetch_err = 0;
    while ((rc = mysql_stmt_fetch(st)) == 0 || rc == MYSQL_DATA_TRUNCATED) {
        rowcount++;
        if (rowcount > ROW_CAP) {
            g_truncated = 1;
            break;
        }
        if (bridge_debug()) fprintf(stderr, "FETCH rc=%d row=%d\n", rc, rowcount);
        if (!first_row) append_sep(";");
        first_row = 0;
        for (unsigned int i = 0; i < cols; i++) {
            column_text(temp, rbuf[i], rlen[i]);
            append_field(temp);
            if (i < cols - 1) append_sep("|");
        }
    }
    if (rc != 0 && rc != MYSQL_DATA_TRUNCATED && rc != MYSQL_NO_DATA) {
        /* ADR-0006: partial rows plus a fetch error must not look like success. */
        fetch_err = 1;
    }
    if (bridge_debug())
        fprintf(stderr, "TOTAL_ROWS=%d first_row=%d G_RESULT_LEN=%zu\n", rowcount, first_row, strlen(G_RESULT));
    if (g_truncated) {
        strncpy(G_RESULT, "ERROR|RESULT_TRUNCATED", RES_CAP);
    } else if (fetch_err) {
        snprintf(G_RESULT, RES_CAP, "ERROR|EXEC_FAILED|%d", mysql_stmt_errno(st));
    } else if (first_row) {
        strncpy(G_RESULT, "ERROR|NO_DATA", RES_CAP);
    }
}

static void prepared_exec(char *sql, int nparams, char **params, int maxparams, int mode) {
    if (!sql) return;
    g_truncated = 0;

    /* WS-PREP-SQL is PIC X(1024) or X(2048) space-padded, not NUL-terminated.
     * Copy a bounded prefix (original 1023 semantics) so a 1024-field never
     * overreads; 2048-fields with queries >1023 would truncate (known gap,
     * tracked by check_cobol_field_sizes — queries in tree are short). */
    char query[1024];
    strncpy(query, sql, 1023);
    query[1023] = '\0';
    trim_trailing_spaces(query);
    if (query[0] == '\0') return;
    if (bridge_debug()) fprintf(stderr, "ROWS_QUERY: %s\n", query);
    MYSQL *conn = G_CONN;
    int own_conn = 0;
    if (conn == NULL) {
        int insecure = 0;
        conn = bridge_connect(&insecure);
        own_conn = 1;
        if (conn == NULL) { set_connect_error(insecure); return; }
    }

    MYSQL_STMT *st = mysql_stmt_init(conn);
    if (st == NULL) {
        strncpy(G_RESULT, "ERROR|STMT_INIT_FAILED", RES_CAP);
        /* pooled: connection kept for reuse */
        return;
    }
    if (mysql_stmt_prepare(st, query, (unsigned long)strlen(query))) {
        snprintf(G_RESULT, RES_CAP, "ERROR|PREPARE_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    char bufs[7][512];
    unsigned long lens[7];
    MYSQL_BIND bind[7];
    memset(bind, 0, sizeof(bind));

    int n = nparams;
    if (n < 0) n = 0;
    if (n > maxparams) n = maxparams;

    for (int i = 0; i < n; i++) {
        memset(bufs[i], 0, sizeof(bufs[i]));
        if (params[i]) { strncpy(bufs[i], params[i], 256); bufs[i][256] = '\0'; }
        trim_trailing_spaces(bufs[i]);
        lens[i] = (unsigned long)strlen(bufs[i]);
        bind[i].buffer_type = MYSQL_TYPE_STRING;
        bind[i].buffer = bufs[i];
        bind[i].buffer_length = 511;
        bind[i].length = &lens[i];
    }
    if (n > 0 && mysql_stmt_bind_param(st, bind)) {
        strncpy(G_RESULT, "ERROR|BIND_FAILED", RES_CAP);
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    if (mysql_stmt_execute(st)) {
        snprintf(G_RESULT, RES_CAP, "ERROR|EXEC_FAILED|%d", mysql_errno(conn));
        mysql_stmt_close(st);
        /* pooled: connection kept for reuse */
        return;
    }

    if (mode == EXEC_LOCK) {
        strncpy(G_RESULT, "SUCCESS|LOCKED", RES_CAP);
    } else if (mode == EXEC_ROWS) {
        fetch_all(st);
    } else {
        fetch_one(st);
    }

    mysql_stmt_close(st);
    /* pooled: connection kept for reuse */
    (void)own_conn;
}

/* --- Thin entry points (COBOL-visible symbols, unchanged) ----------------- */

void SQL_PREPARE_EXEC(char *sql, int nparams,
                      char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    char *params[7] = { p1, p2, p3, p4, p5, p6, NULL };
    prepared_exec(sql, nparams, params, 6, EXEC_ONE);
}

/* Same as SQL_PREPARE_EXEC but with one extra slot, for the CREDIT ledger
 * insert which binds the rate twice (multiply + snapshot) plus the sender. */
void SQL_PREPARE_EXEC7(char *sql, int nparams,
                       char *p1, char *p2, char *p3, char *p4, char *p5, char *p6, char *p7) {
    char *params[7] = { p1, p2, p3, p4, p5, p6, p7 };
    prepared_exec(sql, nparams, params, 7, EXEC_ONE);
}

/* Prepared execute without reading rows. Binds parameters and runs the
 * statement, but does not fetch/bind a result set. Used for a locking
 * `SELECT ... FOR UPDATE` whose rows are not needed; reading them via
 * mysql_stmt_store_result makes MariaDB raise ER_CHECKREAD (1020) under
 * contention, even though the lock itself succeeded. */
void SQL_PREPARE_EXEC_LOCK(char *sql, int nparams,
                           char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    char *params[7] = { p1, p2, p3, p4, p5, p6, NULL };
    prepared_exec(sql, nparams, params, 6, EXEC_LOCK);
}

/* Prepared multi-row execute. Like SQL_PREPARE_EXEC (bound parameters) but
 * concatenates EVERY row: fields joined by '|', rows joined by ';'. Used for
 * paged lists whose LIMIT/OFFSET are supplied by the caller. */
void SQL_PREPARE_EXEC_ROWS(char *sql, int nparams,
                           char *p1, char *p2, char *p3, char *p4, char *p5, char *p6) {
    char *params[7] = { p1, p2, p3, p4, p5, p6, NULL };
    prepared_exec(sql, nparams, params, 6, EXEC_ROWS);
}
