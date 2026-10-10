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
char G_RESULT[1024] = {0};

/* Persistent connection, held only for the span of an explicit transaction. */
static MYSQL *G_CONN = NULL;

static MYSQL *bridge_connect(void) {
    MYSQL *c = mysql_init(NULL);
    if (c == NULL) return NULL;
    if (mysql_real_connect(c, "localhost", "cobol_user", "cobol_pass", "cobol_db", 3306, NULL, 0) == NULL) {
        mysql_close(c);
        return NULL;
    }
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
    memset(result, ' ', 511);
    if (len > 511) len = 511;
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
            strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 1023);
            return;
        }
    }

    fprintf(stderr, "[SQL_BRIDGE] Executing: %s\\n", G_QUERY);

    if (mysql_query(conn, G_QUERY)) {
        strncpy(G_RESULT, "ERROR|QUERY_FAILED", 1023);
        if (own_conn) mysql_close(conn);
        return;
    }

    res = mysql_store_result(conn);
    if (res == NULL) {
        long affected = mysql_affected_rows(conn);
        snprintf(G_RESULT, 1023, "SUCCESS|AFFECTED_%ld", affected);
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
                    strncat(G_RESULT, temp, 1023 - strlen(G_RESULT) - 1);
                } else {
                    strncat(G_RESULT, "NULL", 1023 - strlen(G_RESULT) - 1);
                }
                if (i < num_fields - 1) {
                    strncat(G_RESULT, "|", 1023 - strlen(G_RESULT) - 1);
                }
            }
        } else {
            strncpy(G_RESULT, "ERROR|NO_DATA", 1023);
        }
        mysql_free_result(res);
    }

    if (own_conn) mysql_close(conn);
}

/* --- Transaction control -------------------------------------------------
 * The plain SQL_EXECUTE has no transaction because it connects and
 * disconnects per call. BEGIN opens a persistent connection that the
 * following SQL_EXECUTE calls share until COMMIT/ROLLBACK closes it.
 * ------------------------------------------------------------------------ */

void SQL_BEGIN() {
    if (G_CONN != NULL) {
        mysql_close(G_CONN);
        G_CONN = NULL;
    }
    G_CONN = bridge_connect();
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 1023);
        return;
    }
    if (mysql_query(G_CONN, "START TRANSACTION")) {
        strncpy(G_RESULT, "ERROR|BEGIN_FAILED", 1023);
        mysql_close(G_CONN);
        G_CONN = NULL;
        return;
    }
    strncpy(G_RESULT, "SUCCESS|BEGIN", 1023);
}

void SQL_COMMIT() {
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|NO_TRANSACTION", 1023);
        return;
    }
    if (mysql_query(G_CONN, "COMMIT")) {
        strncpy(G_RESULT, "ERROR|COMMIT_FAILED", 1023);
    } else {
        strncpy(G_RESULT, "SUCCESS|COMMIT", 1023);
    }
    mysql_close(G_CONN);
    G_CONN = NULL;
}

void SQL_ROLLBACK() {
    if (G_CONN == NULL) {
        strncpy(G_RESULT, "ERROR|NO_TRANSACTION", 1023);
        return;
    }
    if (mysql_query(G_CONN, "ROLLBACK")) {
        strncpy(G_RESULT, "ERROR|ROLLBACK_FAILED", 1023);
    } else {
        strncpy(G_RESULT, "SUCCESS|ROLLBACK", 1023);
    }
    mysql_close(G_CONN);
    G_CONN = NULL;
}
