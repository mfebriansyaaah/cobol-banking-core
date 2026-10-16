/*
 * Fail-closed OS entropy.
 *
 * Security-sensitive values (password salts, verification/reset codes and
 * MFA/TOTP secrets) must come from the operating system CSPRNG. The previous
 * code fell back to an unseeded rand() (deterministic) or a fixed constant
 * when /dev/urandom could not be read, which would make codes and secrets
 * predictable (CWE-338). Instead we refuse to continue: aborting is the safe
 * behaviour, because issuing a guessable credential is worse than failing.
 */
#include "random_lib.h"

#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#include <wincrypt.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#endif

static void csprng_unavailable(void) {
    fprintf(stderr,
            "FATAL: OS CSPRNG unavailable; refusing to generate predictable "
            "secrets (fail-closed)\n");
    abort();
}

void secure_random_bytes(unsigned char *buf, size_t n) {
    if (buf == NULL || n == 0) return;

#ifdef _WIN32
    HCRYPTPROV prov = 0;
    if (CryptAcquireContext(&prov, NULL, NULL, PROV_RSA_FULL,
                            CRYPT_VERIFYCONTEXT | CRYPT_SILENT)) {
        BOOL ok = CryptGenRandom(prov, (DWORD)n, (BYTE *)buf);
        CryptReleaseContext(prov, 0);
        if (ok) return;
    }
    csprng_unavailable();
#else
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd != -1) {
        size_t off = 0;
        while (off < n) {
            ssize_t got = read(fd, buf + off, n - off);
            if (got < 0) {
                if (errno == EINTR) continue;
                break;
            }
            if (got == 0) break; /* unexpected EOF */
            off += (size_t)got;
        }
        close(fd);
        if (off == n) return;
    }
    csprng_unavailable();
#endif
}
