/*
 * TOTP (RFC 6238) + base32 for time-based one-time passwords.
 * Self-contained: SHA-1 and HMAC-SHA1 above it, then the TOTP truncation.
 * Compatible with authenticator apps that default to SHA-1 / 6 digits / 30s.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include "random_lib.h"

typedef struct {
    uint32_t state[5];
    uint64_t count;
    uint8_t buffer[64];
} SHA1_CTX;

static uint32_t rol32(uint32_t v, int b) {
    return (uint32_t)((v << b) | (v >> (32 - b)));
}

static void sha1_transform(SHA1_CTX *ctx, const uint8_t block[64]) {
    uint32_t w[80];
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint32_t)block[i * 4] << 24) | ((uint32_t)block[i * 4 + 1] << 16) |
               ((uint32_t)block[i * 4 + 2] << 8) | (uint32_t)block[i * 4 + 3];
    }
    for (int i = 16; i < 80; i++) {
        w[i] = rol32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }
    uint32_t a = ctx->state[0], b = ctx->state[1], c = ctx->state[2];
    uint32_t d = ctx->state[3], e = ctx->state[4];
    for (int i = 0; i < 80; i++) {
        uint32_t f, k;
        if (i < 20)      { f = (b & c) | ((~b) & d);            k = 0x5A827999; }
        else if (i < 40) { f = b ^ c ^ d;                       k = 0x6ED9EBA1; }
        else if (i < 60) { f = (b & c) | (b & d) | (c & d);     k = 0x8F1BBCDC; }
        else             { f = b ^ c ^ d;                       k = 0xCA62C1D6; }
        uint32_t tmp = rol32(a, 5) + f + e + k + w[i];
        e = d; d = c; c = rol32(b, 30); b = a; a = tmp;
    }
    ctx->state[0] += a; ctx->state[1] += b; ctx->state[2] += c;
    ctx->state[3] += d; ctx->state[4] += e;
}

static void sha1_init(SHA1_CTX *ctx) {
    ctx->state[0] = 0x67452301; ctx->state[1] = 0xEFCDAB89;
    ctx->state[2] = 0x98BADCFE; ctx->state[3] = 0x10325476;
    ctx->state[4] = 0xC3D2E1F0;
    ctx->count = 0;
}

static void sha1_update(SHA1_CTX *ctx, const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        ctx->buffer[ctx->count % 64] = data[i];
        ctx->count++;
        if (ctx->count % 64 == 0) {
            sha1_transform(ctx, ctx->buffer);
        }
    }
}

static void sha1_final(SHA1_CTX *ctx, uint8_t out[20]) {
    uint64_t bitlen = ctx->count * 8;
    size_t idx = (size_t)(ctx->count % 64);
    ctx->buffer[idx++] = 0x80;
    if (idx > 56) {
        while (idx < 64) ctx->buffer[idx++] = 0;
        sha1_transform(ctx, ctx->buffer);
        idx = 0;
    }
    while (idx < 56) ctx->buffer[idx++] = 0;
    for (int i = 0; i < 8; i++) {
        ctx->buffer[56 + i] = (uint8_t)(bitlen >> (56 - i * 8));
    }
    sha1_transform(ctx, ctx->buffer);
    for (int i = 0; i < 5; i++) {
        out[i * 4]     = (uint8_t)(ctx->state[i] >> 24);
        out[i * 4 + 1] = (uint8_t)(ctx->state[i] >> 16);
        out[i * 4 + 2] = (uint8_t)(ctx->state[i] >> 8);
        out[i * 4 + 3] = (uint8_t)(ctx->state[i]);
    }
}

static void hmac_sha1(const uint8_t *key, size_t keylen,
                      const uint8_t *msg, size_t msglen, uint8_t out[20]) {
    uint8_t k[64];
    memset(k, 0, sizeof(k));
    if (keylen > 64) {
        SHA1_CTX c;
        sha1_init(&c);
        sha1_update(&c, key, keylen);
        sha1_final(&c, k);
    } else {
        memcpy(k, key, keylen);
    }
    uint8_t ipad[64], opad[64];
    for (int i = 0; i < 64; i++) {
        ipad[i] = k[i] ^ 0x36;
        opad[i] = k[i] ^ 0x5c;
    }
    uint8_t inner[20];
    SHA1_CTX c;
    sha1_init(&c);
    sha1_update(&c, ipad, 64);
    sha1_update(&c, msg, msglen);
    sha1_final(&c, inner);
    sha1_init(&c);
    sha1_update(&c, opad, 64);
    sha1_update(&c, inner, 20);
    sha1_final(&c, out);
}

static const char B32_ALPHABET[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

static void base32_encode(const uint8_t *in, size_t len, char *out) {
    uint32_t buffer = 0;
    int bits = 0;
    size_t o = 0;
    for (size_t i = 0; i < len; i++) {
        buffer = (buffer << 8) | in[i];
        bits += 8;
        while (bits >= 5) {
            out[o++] = B32_ALPHABET[(buffer >> (bits - 5)) & 0x1f];
            bits -= 5;
        }
    }
    if (bits > 0) {
        out[o++] = B32_ALPHABET[(buffer << (5 - bits)) & 0x1f];
    }
    out[o] = '\0';
}

static int base32_decode(const char *in, uint8_t *out, size_t max) {
    uint32_t buffer = 0;
    int bits = 0;
    size_t o = 0;
    for (const char *p = in; *p; p++) {
        char c = *p;
        if (c == '=') break;
        int v = -1;
        if (c >= 'A' && c <= 'Z') v = c - 'A';
        else if (c >= 'a' && c <= 'z') v = c - 'a';
        else if (c >= '2' && c <= '7') v = c - '2' + 26;
        else continue; /* skip separators/spaces */
        buffer = (buffer << 5) | (uint32_t)v;
        bits += 5;
        if (bits >= 8) {
            if (o >= max) return -1;
            out[o++] = (uint8_t)((buffer >> (bits - 8)) & 0xff);
            bits -= 8;
        }
    }
    return (int)o;
}

static uint32_t totp_at(const uint8_t *key, size_t keylen, uint64_t counter) {
    uint8_t msg[8];
    for (int i = 0; i < 8; i++) {
        msg[7 - i] = (uint8_t)(counter >> (i * 8));
    }
    uint8_t mac[20];
    hmac_sha1(key, keylen, msg, 8, mac);
    int off = mac[19] & 0x0f;
    uint32_t bin = ((uint32_t)(mac[off] & 0x7f) << 24) |
                   ((uint32_t)mac[off + 1] << 16) |
                   ((uint32_t)mac[off + 2] << 8) |
                   (uint32_t)mac[off + 3];
    return bin % 1000000;
}

/**
 * Generate a fresh base32 TOTP secret (160-bit).
 */
void generate_mfa_secret(char *out) {
    if (out == NULL) return;
    uint8_t key[20];
    /* Fail-closed OS entropy: no rand() fallback. */
    secure_random_bytes(key, sizeof(key));
    base32_encode(key, sizeof(key), out);
}

/**
 * Verify a 6-digit TOTP code against a base32 secret, allowing +/- one step
 * (30s) of clock drift. Writes "1" to result on a match, "0" otherwise.
 */
void totp_verify(char *secret_b32, char *code, char *result) {
    if (secret_b32 == NULL || code == NULL || result == NULL) return;
    /* Single-char out-param: no terminator is written (see verify_password). */
    result[0] = '0';

    char digits[16];
    int n = 0;
    for (char *p = code; *p && n < 15; p++) {
        if (*p >= '0' && *p <= '9') digits[n++] = *p;
        else break;
    }
    digits[n] = '\0';
    if (n != 6) return;

    /* COBOL fields are space padded and not NUL terminated: copy the secret
     * up to the first space/NUL so the decode stays in bounds. */
    char secret[64];
    size_t slen = 0;
    while (slen < sizeof(secret) - 1) {
        char c = secret_b32[slen];
        if (c == '\0' || c == ' ') break;
        secret[slen] = c;
        slen++;
    }
    secret[slen] = '\0';

    uint8_t key[64];
    int kl = base32_decode(secret, key, sizeof(key));
    if (kl <= 0) return;

    uint32_t want = (uint32_t)atoi(digits);
    long long step = (long long)(time(NULL) / 30);
    for (int d = -1; d <= 1; d++) {
        long long c = step + d;
        if (c < 0) continue;
        if (totp_at(key, (size_t)kl, (uint64_t)c) == want) {
            result[0] = '1';
            return;
        }
    }
}
