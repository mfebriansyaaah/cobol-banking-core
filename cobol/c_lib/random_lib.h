/*
 * Central OS entropy source for every security-sensitive random value
 * (password salt, verification/reset codes, MFA/TOTP secrets).
 */
#ifndef RANDOM_LIB_H
#define RANDOM_LIB_H

#include <stddef.h>

/*
 * Fill buf with n cryptographically secure random bytes from the operating
 * system CSPRNG. Fails closed: if the OS source is unavailable the process is
 * aborted rather than silently returning predictable bytes (there is no
 * rand()/constant fallback).
 */
void secure_random_bytes(unsigned char *buf, size_t n);

#endif
