#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Main Entry Point in C
 * Passes parameters explicitly to avoid linkage descriptor issues.
 */

extern void cob_init(int *argc, char **argv);
extern void core_engine(char *action, char *p1, char *p2, char *p3, char *p4);

int main(int argc, char **argv) {
    cob_init(&argc, argv);

    if (argc < 2) {
        printf("ERROR|MISSING_ACTION\n");
        return 1;
    }

    char action[101] = {0};
    char p1[101] = {0};
    char p2[101] = {0};
    char p3[101] = {0};
    char p4[101] = {0};

    if (argc >= 2) strncpy(action, argv[1], 100);
    if (argc >= 3) strncpy(p1, argv[2], 100);
    if (argc >= 4) strncpy(p2, argv[3], 100);
    if (argc >= 5) strncpy(p3, argv[4], 100);
    if (argc >= 6) strncpy(p4, argv[5], 100);

    // Call COBOL with explicit pointers
    core_engine(action, p1, p2, p3, p4);

    return 0;
}
