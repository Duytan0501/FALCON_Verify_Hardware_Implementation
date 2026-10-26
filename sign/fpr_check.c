#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
typedef uint64_t fpr;
int fpr_lt(fpr x, fpr y)
{
    int cc0 = *(int64_t *)&x < *(int64_t *)&y;
    int cc1 = *(int64_t *)&x > *(int64_t *)&y;
    return cc0 ^ ((cc0 ^ cc1) & (int)((x & y) >> 63));
}

fpr FPR(int s, int e, uint64_t m)
{
    fpr x;
    uint32_t t;
    unsigned f;
    e += 1076;
    t = (uint32_t)e >> 31;
    m &= (uint64_t)t - 1;
    t = (uint32_t)(m >> 54);
    e &= -(int)t;
    x = (((uint64_t)s << 63) | (m >> 2)) + ((uint64_t)(uint32_t)e << 52);
    f = (unsigned)m & 7U;
    x += (0xC8U >> f) & 1;
    return x;
}
uint64_t rand64()
{
    return ((uint64_t)rand() << 32) | rand();
}
static inline uint64_t fpr_ursh(uint64_t x, int n)
{
    x ^= (x ^ (x >> 32)) & -(uint64_t)(n >> 5);
    return x >> (n & 31);
}

static inline int64_t fpr_irsh(int64_t x, int n)
{
    x ^= (x ^ (x >> 32)) & -(int64_t)(n >> 5);
    return x >> (n & 31);
}

static inline uint64_t fpr_ulsh(uint64_t x, int n)
{
    x ^= (x ^ (x << 32)) & -(uint64_t)(n >> 5);
    return x << (n & 31);
}

// --- Thêm 3 hàm cần test từ fpr_2.h ---
static inline int64_t fpr_trunc(fpr x)
{
    uint64_t t, xu;
    int e, cc;
    e = (int)(x >> 52) & 0x7FF;
    xu = ((x << 10) | ((uint64_t)1 << 62)) & (((uint64_t)1 << 63) - 1);
    cc = 1085 - e;
    xu = fpr_ursh(xu, cc & 63);
    xu &= -(uint64_t)((uint32_t)(cc - 64) >> 31);
    t = x >> 63;
    xu = (xu ^ -t) + t;
    return *(int64_t *)&xu;
}

static inline int64_t fpr_floor(fpr x)
{
    uint64_t t;
    int64_t xi;
    int e, cc;
    e = (int)(x >> 52) & 0x7FF;
    t = x >> 63;
    xi = (int64_t)(((x << 10) | ((uint64_t)1 << 62)) & (((uint64_t)1 << 63) - 1));
    xi = (xi ^ -(int64_t)t) + (int64_t)t;
    cc = 1085 - e;
    xi = fpr_irsh(xi, cc & 63);
    xi ^= (xi ^ -(int64_t)t) & -(int64_t)((uint32_t)(63 - cc) >> 31);
    return xi;
}

static inline int64_t fpr_rint(fpr x)
{
    uint64_t m, d;
    int e;
    uint32_t s, dd, f;
    m = ((x << 10) | ((uint64_t)1 << 62)) & (((uint64_t)1 << 63) - 1);
    e = 1085 - ((int)(x >> 52) & 0x7FF);
    m &= -(uint64_t)((uint32_t)(e - 64) >> 31);
    e &= 63;
    d = fpr_ulsh(m, 63 - e);
    dd = (uint32_t)d | ((uint32_t)(d >> 32) & 0x1FFFFFFF);
    f = (uint32_t)(d >> 61) | ((dd | -dd) >> 31);
    m = fpr_ursh(m, e) + (uint64_t)((0xC8U >> f) & 1U);
    s = (uint32_t)(x >> 63);
    return ((int64_t)m ^ -(int64_t)s) + (int64_t)s;
}
int main()
{
    srand(time(NULL));
    int num_tests = 10000;
    FILE *f_lt = fopen("test_lt.txt", "w");
    for (int i = 0; i < num_tests; i++)
    {
        fpr x = rand64();
        fpr y = rand64();
        if (i % 4 == 0)
        {
            x |= (1ULL << 63);
            y |= (1ULL << 63);
        }
        int z = fpr_lt(x, y);
        fprintf(f_lt, "%016llx %016llx %x\n", x, y, z);
    }
    fclose(f_lt);
    FILE *f_pack = fopen("test_pack.txt", "w");
    for (int i = 0; i < num_tests; i++)
    {
        int s = rand() % 2;
        int e = (rand() % 3000) - 1500;
        uint64_t m = rand64();
        fpr z = FPR(s, e, m);
        fprintf(f_pack, "%x %08x %016llx %016llx\n", s, (uint32_t)e, m, z);
    }
    fclose(f_pack);
    FILE *f_round = fopen("test_round.txt", "w");
    for (int i = 0; i < num_tests; i++)
    {
        fpr x = rand64();
        if (i % 2 == 0)
        {
            uint64_t e_test = 1023 + (rand() % 100);
            x = (x & ~(0x7FFULL << 52)) | (e_test << 52);
        }
        int64_t z_trunc = fpr_trunc(x);
        int64_t z_floor = fpr_floor(x);
        int64_t z_rint = fpr_rint(x);

        fprintf(f_round, "%016llx %016llx %016llx %016llx\n", x, (uint64_t)z_trunc, (uint64_t)z_floor, (uint64_t)z_rint);
    }
    fclose(f_round);
    return 0;
}