#include "sha3.h"

using namespace std;

static const uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL,
    0x800000000000808AULL, 0x8000000080008000ULL,
    0x000000000000808BULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008AULL, 0x0000000000000088ULL,
    0x0000000080008009ULL, 0x000000008000000AULL,
    0x000000008000808BULL, 0x800000000000008BULL,
    0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800AULL, 0x800000008000000AULL,
    0x8000000080008081ULL, 0x8000000000008080ULL,
    0x0000000080000001ULL, 0x8000000080008008ULL
};

static const int RHO[5][5] = {
    { 0, 36,  3, 41, 18},
    { 1, 44, 10, 45,  2},
    {62,  6, 43, 15, 61},
    {28, 55, 25, 21, 56},
    {27, 20, 39,  8, 14}
};

uint64_t SHA3::rot64(uint64_t x, int n)
{
    return (n == 0) ? x : ((x << n) | (x >> (64 - n)));
}

uint64_t SHA3::load_lane(const uint8_t *block, size_t lane_index)
{
    uint64_t lane = 0;
    for (int b = 0; b < 8; b++)
        lane |= (uint64_t)block[lane_index * 8 + b] << (b * 8);
    return lane;
}

void SHA3::theta(uint64_t state[5][5], uint64_t C[5], uint64_t D[5])
{
    for (int x = 0; x < 5; x++)
        C[x] = state[x][0] ^ state[x][1] ^ state[x][2]
             ^ state[x][3] ^ state[x][4];

    for (int x = 0; x < 5; x++)
        D[x] = C[(x+4)%5] ^ rot64(C[(x+1)%5], 1);

    for (int x = 0; x < 5; x++)
        for (int y = 0; y < 5; y++)
            state[x][y] ^= D[x];
}

void SHA3::rho_pi(uint64_t state[5][5], uint64_t B[5][5])
{
    for (int x = 0; x < 5; x++)
        for (int y = 0; y < 5; y++)
            B[y][(2*x + 3*y) % 5] = rot64(state[x][y], RHO[x][y]);
}

void SHA3::chi(uint64_t state[5][5], uint64_t B[5][5])
{
    for (int x = 0; x < 5; x++)
        for (int y = 0; y < 5; y++)
            state[x][y] = B[x][y] ^ (~B[(x+1)%5][y] & B[(x+2)%5][y]);
}

void SHA3::iota(uint64_t state[5][5], uint64_t rc)
{
    state[0][0] ^= rc;
}

void SHA3::keccak_f(uint64_t state[5][5])
{
    uint64_t C[5], D[5], B[5][5];

    for (int round = 0; round < 24; round++)
    {
        theta(state, C, D);
        rho_pi(state, B);
        chi(state, B);
        iota(state, RC[round]);
    }
}

void SHA3::absorb_block(uint64_t state[5][5], const uint8_t *block, size_t rate_bytes)
{
    for (size_t i = 0; i < rate_bytes / 8; i++)
        state[i % 5][i / 5] ^= load_lane(block, i);

    keccak_f(state);
}

void SHA3::apply_padding(uint8_t *buf, size_t buf_pos, size_t rate_bytes)
{
    buf[buf_pos]        ^= 0x06;
    buf[rate_bytes - 1] ^= 0x80;
}

void SHA3::extract_digest(uint64_t state[5][5], uint8_t *out, size_t digest_bytes)
{
    for (size_t i = 0; i < digest_bytes; i++)
    {
        size_t x = (i / 8) % 5;
        size_t y = (i / 8) / 5;
        out[i] = (uint8_t)(state[x][y] >> ((i % 8) * 8));
    }
}

void SHA3::keccak(const uint8_t *in, size_t length, uint8_t *out,
                  size_t rate_bytes, size_t digest_bytes)
{
    uint64_t state[5][5];
    memset(state, 0, sizeof(state));

    uint8_t *buf = (uint8_t *) malloc(rate_bytes);

    size_t offset  = 0;
    size_t buf_pos = 0;

    while (offset < length)
    {
        size_t take = rate_bytes - buf_pos;
        if (take > length - offset)
            take = length - offset;

        memcpy(buf + buf_pos, in + offset, take);
        buf_pos += take;
        offset  += take;

        if (buf_pos == rate_bytes)
        {
            absorb_block(state, buf, rate_bytes);
            memset(buf, 0, rate_bytes);
            buf_pos = 0;
        }
    }

    memset(buf + buf_pos, 0, rate_bytes - buf_pos);
    apply_padding(buf, buf_pos, rate_bytes);
    absorb_block(state, buf, rate_bytes);

    free(buf);

    extract_digest(state, out, digest_bytes);
}

void SHA3::SHA3_224(uint8_t *in, int length, uint8_t *out)
{
    keccak(in, (size_t)length, out, (1600-448)/8, 28);
}

void SHA3::SHA3_256(uint8_t *in, int length, uint8_t *out)
{
    keccak(in, (size_t)length, out, (1600-512)/8, 32);
}

void SHA3::SHA3_384(uint8_t *in, int length, uint8_t *out)
{
    keccak(in, (size_t)length, out, (1600-768)/8, 48);
}

void SHA3::SHA3_512(uint8_t *in, int length, uint8_t *out)
{
    keccak(in, (size_t)length, out, (1600-1024)/8, 64);
}