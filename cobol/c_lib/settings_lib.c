/*
 * Tiny settings helper: let COBOL read an operational limit from the
 * environment, falling back to a compiled default. COBOL passes the name and
 * default as (possibly space-padded) fields, so bound the copies instead of
 * relying on NUL termination.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void env_or(char *name, char *def, char *out) {
    if (name == NULL || def == NULL || out == NULL) return;

    char nbuf[64];
    char dbuf[64];
    size_t n = 0;
    size_t d = 0;

    while (n < sizeof(nbuf) - 1 && name[n] != '\0' && name[n] != ' ') {
        nbuf[n] = name[n];
        n++;
    }
    nbuf[n] = '\0';

    while (d < sizeof(dbuf) - 1 && def[d] != '\0' && def[d] != ' ') {
        dbuf[d] = def[d];
        d++;
    }
    dbuf[d] = '\0';

    const char *v = getenv(nbuf);
    if (v == NULL || v[0] == '\0') v = dbuf;

    /* Keep digits only; the caller parses the result as a number. Write no
     * terminator: the COBOL field is space-padded by the caller, and an
     * embedded NUL would upset NUMVAL. */
    size_t o = 0;
    for (const char *p = v; *p != '\0' && o < 30; p++) {
        if (*p >= '0' && *p <= '9') out[o++] = *p;
    }
}

/*
 * Raw variant of env_or for whole-unit money caps. Copies the value verbatim
 * (bounded, no terminator) instead of stripping to digits, so COBOL can tell
 * a dotted or malformed setting apart from a plain integer and fail closed
 * instead of silently enforcing a different number.
 */
void env_or_raw(char *name, char *def, char *out) {
    if (name == NULL || def == NULL || out == NULL) return;

    char nbuf[64];
    char dbuf[64];
    size_t n = 0;
    size_t d = 0;

    while (n < sizeof(nbuf) - 1 && name[n] != '\0' && name[n] != ' ') {
        nbuf[n] = name[n];
        n++;
    }
    nbuf[n] = '\0';

    while (d < sizeof(dbuf) - 1 && def[d] != '\0' && def[d] != ' ') {
        dbuf[d] = def[d];
        d++;
    }
    dbuf[d] = '\0';

    const char *v = getenv(nbuf);
    if (v == NULL || v[0] == '\0') v = dbuf;

    size_t o = 0;
    for (const char *p = v; *p != '\0' && o < 30; p++) {
        out[o++] = *p;
    }
}
