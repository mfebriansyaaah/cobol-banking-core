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
    strncpy(G_QUERY, query, 1023);
    trim_trailing_spaces(G_QUERY);
}

void GET_RESULT(char *result) {
    if (!result) return;
    strncpy(result, G_RESULT, 1023);
}

void SQL_EXECUTE() {
    MYSQL *conn;
    MYSQL_RES *res;
    MYSQL_ROW row;

    conn = mysql_init(NULL);
    if (conn == NULL) {
        strncpy(G_RESULT, "ERROR|DB_INIT_FAILED", 1023);
        return;
    }

    if (mysql_real_connect(conn, "localhost", "cobol_user", "cobol_pass", "cobol_db", 3306, NULL, 0) == NULL) {
        strncpy(G_RESULT, "ERROR|DB_CONN_FAILED", 1023);
        mysql_close(conn);
        return;
    }

    if (mysql_query(conn, G_QUERY)) {
        strncpy(G_RESULT, "ERROR|QUERY_FAILED", 1023);
        mysql_close(conn);
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
                    strncat(G_RESULT, row[i], 1023 - strlen(G_RESULT) - 1);
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

    mysql_close(conn);
}
