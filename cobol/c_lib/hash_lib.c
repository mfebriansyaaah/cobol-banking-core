#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#include <wincrypt.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

/**
 * Simple Password Hash Wrapper for COBOL
 */
void hash_password(char* password, char* output_hash) {
    if (password == NULL || output_hash == NULL) return;

    unsigned long hash = 5381;
    int c;
    
    while ((c = *password++)) {
        hash = ((hash << 5) + hash) + c; 
    }

    sprintf(output_hash, "HASH_%lx", hash);
}

/**
 * Fetch a secure random 32-bit integer from the OS
 */
static unsigned int get_secure_random_uint32() {
    unsigned int rand_val = 0;
#ifdef _WIN32
    HCRYPTPROV hProvider = 0;
    if (CryptAcquireContext(&hProvider, NULL, NULL, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT | CRYPT_SILENT)) {
        CryptGenRandom(hProvider, sizeof(rand_val), (BYTE*)&rand_val);
        CryptReleaseContext(hProvider, 0);
    }
#else
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd != -1) {
        read(fd, &rand_val, sizeof(rand_val));
        close(fd);
    }
#endif
    if (rand_val == 0) rand_val = 123456; // Fallback
    return rand_val;
}

/**
 * Generate a random 6-digit code for verification
 */
void generate_random_code(char* output_code) {
    if (output_code == NULL) return;
    
    // Seed random number generator
    static int seeded = 0;
    if (!seeded) {
        srand(time(NULL));
        seeded = 1;
    }

    int code = (rand() % 900000) + 100000; // Generates number between 100000 and 999999
    sprintf(output_code, "%06d", code);
}
