/*
 * SECURITY UPDATE: The previous djb2 hashing algorithm has been identified
 * as cryptographically insecure for production password storage.
 * We are migrating this to SHA-256 to meet Enterprise Banking security standards.
 * This implementation is self-contained to avoid external dependencies.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <stddef.h>
#ifdef _WIN32
#include <windows.h>
#include <wincrypt.h>
#endif
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

typedef struct {
    uint8_t data[64];
    uint32_t datalen;
    unsigned long long bitlen;
    uint32_t state[8];
} SHA256_CTX;

static const uint32_t k[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

#define ROTLEFT(a,b) (((a) << (b)) | ((a) >> (32-(b))))
#define ROTRIGHT(a,b) (((a) >> (b)) | ((a) << (32-(b))))

#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2) ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6) ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x) (ROTRIGHT(x,7) ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

void sha256_init(SHA256_CTX *ctx) {
    ctx->datalen = 0;
    ctx->bitlen = 0;
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
}

static void sha256_transform(SHA256_CTX *ctx, const uint8_t data[]) {
    uint32_t a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];

    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | (data[j + 3]);
    for ( ; i < 64; ++i)
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];

    a = ctx->state[0]; b = ctx->state[1]; c = ctx->state[2]; d = ctx->state[3];
    e = ctx->state[4]; f = ctx->state[5]; g = ctx->state[6]; h = ctx->state[7];

    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    ctx->state[0] += a; ctx->state[1] += b; ctx->state[2] += c; ctx->state[3] += d;
    ctx->state[4] += e; ctx->state[5] += f; ctx->state[6] += g; ctx->state[7] += h;
}

void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len) {
    uint32_t i;
    for (i = 0; i < len; ++i) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

void sha256_final(SHA256_CTX *ctx, uint8_t hash[]) {
    uint32_t i;
    i = ctx->datalen;
    if (ctx->datalen < 56) {
        ctx->data[i++] = 0x80;
        while (i < 56) ctx->data[i++] = 0x00;
    } else {
        ctx->data[i++] = 0x80;
        while (i < 64) ctx->data[i++] = 0x00;
        sha256_transform(ctx, ctx->data);
        memset(ctx->data, 0, 56);
    }
    ctx->bitlen += ctx->datalen * 8;
    ctx->data[63] = ctx->bitlen;
    ctx->data[62] = ctx->bitlen >> 8;
    ctx->data[61] = ctx->bitlen >> 16;
    ctx->data[60] = ctx->bitlen >> 24;
    ctx->data[59] = ctx->bitlen >> 32;
    ctx->data[58] = ctx->bitlen >> 40;
    ctx->data[57] = ctx->bitlen >> 48;
    ctx->data[56] = ctx->bitlen >> 56;
    sha256_transform(ctx, ctx->data);
    for (i = 0; i < 4; ++i) {
        hash[i]      = (ctx->state[0] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 4]  = (ctx->state[1] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 8]  = (ctx->state[2] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 12] = (ctx->state[3] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 16] = (ctx->state[4] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 20] = (ctx->state[5] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 24] = (ctx->state[6] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 28] = (ctx->state[7] >> (24 - i * 8)) & 0x000000ff;
    }
}

/**
 * Simple Password Hash Wrapper for COBOL
 */
void hash_password(char* password, char* output_hash) {
    if (password == NULL || output_hash == NULL) return;

    SHA256_CTX ctx;
    uint8_t hash[32];
    
    sha256_init(&ctx);
    sha256_update(&ctx, (uint8_t*)password, strlen(password));
    sha256_final(&ctx, hash);

    sprintf(output_hash, "SHA256_");
    for (int i = 0; i < 32; i++) {
        sprintf(output_hash + 7 + (i * 2), "%02x", hash[i]);
    }
}

/* ------------------------------------------------------------------ *
 * Slow KDF: PBKDF2-HMAC-SHA256 (self-contained, reuses sha256 above). *
 * ------------------------------------------------------------------ */

#define PBKDF2_ITERATIONS 100000
#define PBKDF2_SALT_BYTES 16

static void bytes_to_hex(const uint8_t *in, size_t n, char *out) {
    static const char *hx = "0123456789abcdef";
    for (size_t i = 0; i < n; i++) {
        out[i * 2] = hx[(in[i] >> 4) & 0xf];
        out[i * 2 + 1] = hx[in[i] & 0xf];
    }
    out[n * 2] = '\0';
}

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int hex_to_bytes(const char *hex, uint8_t *out, size_t max) {
    size_t n = 0;
    while (hex[0] && hex[1]) {
        int hi = hex_nibble(hex[0]);
        int lo = hex_nibble(hex[1]);
        if (hi < 0 || lo < 0 || n >= max) return -1;
        out[n++] = (uint8_t)((hi << 4) | lo);
        hex += 2;
    }
    return (int)n;
}

static void hmac_sha256(const uint8_t *key, size_t keylen,
                        const uint8_t *msg, size_t msglen, uint8_t out[32]) {
    uint8_t k[64];
    memset(k, 0, sizeof(k));
    if (keylen > 64) {
        SHA256_CTX kc;
        sha256_init(&kc);
        sha256_update(&kc, key, keylen);
        sha256_final(&kc, k);
    } else {
        memcpy(k, key, keylen);
    }

    uint8_t ipad[64], opad[64];
    for (int i = 0; i < 64; i++) {
        ipad[i] = k[i] ^ 0x36;
        opad[i] = k[i] ^ 0x5c;
    }

    uint8_t inner[32];
    SHA256_CTX c;
    sha256_init(&c);
    sha256_update(&c, ipad, 64);
    sha256_update(&c, msg, msglen);
    sha256_final(&c, inner);

    sha256_init(&c);
    sha256_update(&c, opad, 64);
    sha256_update(&c, inner, 32);
    sha256_final(&c, out);
}

/* Single-block PBKDF2 (dkLen == 32 == hash size). */
static void pbkdf2_sha256(const uint8_t *pass, size_t passlen,
                          const uint8_t *salt, size_t saltlen,
                          uint32_t iters, uint8_t out[32]) {
    uint8_t msg[PBKDF2_SALT_BYTES + 4];
    memcpy(msg, salt, saltlen);
    msg[saltlen + 0] = 0;
    msg[saltlen + 1] = 0;
    msg[saltlen + 2] = 0;
    msg[saltlen + 3] = 1;

    uint8_t u[32], t[32];
    hmac_sha256(pass, passlen, msg, saltlen + 4, u);
    memcpy(t, u, 32);
    for (uint32_t i = 1; i < iters; i++) {
        hmac_sha256(pass, passlen, u, 32, u);
        for (int j = 0; j < 32; j++) t[j] ^= u[j];
    }
    memcpy(out, t, 32);
}

static void random_salt(uint8_t *buf, size_t n) {
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd != -1) {
        ssize_t got = read(fd, buf, n);
        close(fd);
        if (got == (ssize_t)n) return;
    }
    for (size_t i = 0; i < n; i++) buf[i] = (uint8_t)(rand() & 0xff);
}

static size_t rtrim_len(const char *s, size_t max) {
    size_t n = 0;
    while (n < max && s[n] != '\0') n++;
    while (n > 0 && (s[n - 1] == ' ' || s[n - 1] == '\0')) n--;
    return n;
}

/**
 * Password hash with a slow KDF. Format: PBKDF2$<iters>$<salt hex>$<key hex>.
 */
void hash_password_v2(char *password, char *output_hash) {
    if (password == NULL || output_hash == NULL) return;
    size_t plen = rtrim_len(password, 100);
    uint8_t salt[PBKDF2_SALT_BYTES];
    random_salt(salt, sizeof(salt));
    uint8_t key[32];
    pbkdf2_sha256((const uint8_t *)password, plen, salt, sizeof(salt), PBKDF2_ITERATIONS, key);

    char salt_hex[PBKDF2_SALT_BYTES * 2 + 1];
    char key_hex[65];
    bytes_to_hex(salt, sizeof(salt), salt_hex);
    bytes_to_hex(key, sizeof(key), key_hex);
    sprintf(output_hash, "PBKDF2$%d$%s$%s", PBKDF2_ITERATIONS, salt_hex, key_hex);
}

/**
 * Verify a password against a stored hash (PBKDF2 or legacy SHA256).
 * Writes "1" to result on a match, "0" otherwise.
 */
void verify_password(char *password, char *stored_hash, char *result) {
    if (password == NULL || stored_hash == NULL || result == NULL) return;
    result[0] = '0';
    result[1] = '\0';

    size_t plen = rtrim_len(password, 100);
    char stored[256];
    size_t slen = rtrim_len(stored_hash, 255);
    memcpy(stored, stored_hash, slen);
    stored[slen] = '\0';

    if (strncmp(stored, "PBKDF2$", 7) == 0) {
        char *save = stored;
        char *iter_s = strtok(save + 7, "$");
        char *salt_s = strtok(NULL, "$");
        char *key_s = strtok(NULL, "$");
        if (!iter_s || !salt_s || !key_s) return;

        int iters = atoi(iter_s);
        uint8_t salt[PBKDF2_SALT_BYTES];
        int saltlen = hex_to_bytes(salt_s, salt, sizeof(salt));
        if (saltlen <= 0 || iters <= 0) return;

        uint8_t key[32];
        pbkdf2_sha256((const uint8_t *)password, plen, salt, (size_t)saltlen, (uint32_t)iters, key);
        char key_hex[65];
        bytes_to_hex(key, sizeof(key), key_hex);
        if (strcmp(key_hex, key_s) == 0) {
            result[0] = '1';
        }
    } else if (strncmp(stored, "SHA256_", 7) == 0) {
        uint8_t hash[32];
        SHA256_CTX c;
        sha256_init(&c);
        sha256_update(&c, (uint8_t *)password, plen);
        sha256_final(&c, hash);
        char hash_hex[65];
        bytes_to_hex(hash, sizeof(hash), hash_hex);
        if (strcmp(hash_hex, stored + 7) == 0) {
            result[0] = '1';
        }
    }
}

/**
 * Fetch a secure random 32-bit integer from the OS
 */static unsigned int get_secure_random_uint32() {
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
 * Generate a cryptographically secure random 6-digit code for verification.
 * Note: Replaced stdlib rand() with OS-level secure RNG to prevent predictability 
 * in verification codes (CWE-338).
 */
void generate_random_code(char* output_code) {
    if (output_code == NULL) return;
    
    unsigned int secure_val = get_secure_random_uint32();
    int code = (secure_val % 900000) + 100000;
    sprintf(output_code, "%06d", code);
}
