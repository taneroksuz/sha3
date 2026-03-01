#ifndef SHA3_H
#define SHA3_H

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <cerrno>
#include <fstream>
#include <iostream>

using namespace std;

class SHA3
{
  private:

    static uint64_t rot64(uint64_t x, int n);

    void keccak_f(uint64_t state[5][5]);

    void absorb_block(uint64_t state[5][5], const uint8_t *block, size_t rate_bytes);

    void apply_padding(uint8_t *buf, size_t buf_pos, size_t rate_bytes);

    void extract_digest(uint64_t state[5][5], uint8_t *out, size_t digest_bytes);

    void keccak(const uint8_t *in, size_t length, uint8_t *out,
                size_t rate_bytes, size_t digest_bytes);

  public:

    void SHA3_224(uint8_t *in, int length, uint8_t *out);

    void SHA3_256(uint8_t *in, int length, uint8_t *out);

    void SHA3_384(uint8_t *in, int length, uint8_t *out);

    void SHA3_512(uint8_t *in, int length, uint8_t *out);

};

#endif