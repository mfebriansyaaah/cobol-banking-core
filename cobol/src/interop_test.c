#include <stdio.h>

/* Simple test function to see what GnuCOBOL actually sends */
void TEST_CALL(char *data, int len) {
    printf("C-SIDE: Received pointer %p\n", (void*)data);
    if (data) {
        printf("C-SIDE: First 10 bytes: ");
        for(int i=0; i<10; i++) {
            printf("%02x ", (unsigned char)data[i]);
        }
        printf("\n");
        printf("C-SIDE: As string: %s\n", data);
    }
}
