#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

typedef uint64_t fpr;

static uint64_t rng_state = 0xFA1C051220261123ULL;

static inline uint64_t rand64(void)
{
    uint64_t x = rng_state;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    rng_state = x;
    return x * 0x2545F4914F6CDD1DULL;
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

#define FPR_NORM64(m, e)                                 \
    do                                                   \
    {                                                    \
        uint32_t nt;                                     \
        (e) -= 63;                                       \
        nt = (uint32_t)((m) >> 32);                      \
        nt = (nt | -nt) >> 31;                           \
        (m) ^= ((m) ^ ((m) << 32)) & ((uint64_t)nt - 1); \
        (e) += (int)(nt << 5);                           \
        nt = (uint32_t)((m) >> 48);                      \
        nt = (nt | -nt) >> 31;                           \
        (m) ^= ((m) ^ ((m) << 16)) & ((uint64_t)nt - 1); \
        (e) += (int)(nt << 4);                           \
        nt = (uint32_t)((m) >> 56);                      \
        nt = (nt | -nt) >> 31;                           \
        (m) ^= ((m) ^ ((m) << 8)) & ((uint64_t)nt - 1);  \
        (e) += (int)(nt << 3);                           \
        nt = (uint32_t)((m) >> 60);                      \
        nt = (nt | -nt) >> 31;                           \
        (m) ^= ((m) ^ ((m) << 4)) & ((uint64_t)nt - 1);  \
        (e) += (int)(nt << 2);                           \
        nt = (uint32_t)((m) >> 62);                      \
        nt = (nt | -nt) >> 31;                           \
        (m) ^= ((m) ^ ((m) << 2)) & ((uint64_t)nt - 1);  \
        (e) += (int)(nt << 1);                           \
        nt = (uint32_t)((m) >> 63);                      \
        (m) ^= ((m) ^ ((m) << 1)) & ((uint64_t)nt - 1);  \
        (e) += (int)(nt);                                \
    } while (0)

static fpr FPR(int s, int e, uint64_t m)
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

static int fpr_lt(fpr x, fpr y)
{
    int64_t sx = (int64_t)x;
    int64_t sy = (int64_t)y;
    int cc0 = (sx < sy);
    int cc1 = (sx > sy);
    return cc0 ^ ((cc0 ^ cc1) & (int)((x & y) >> 63));
}

static inline fpr fpr_neg(fpr x)
{
    return x ^ ((uint64_t)1 << 63);
}

static inline fpr fpr_half(fpr x)
{
    uint32_t t;
    x -= (uint64_t)1 << 52;
    t = (((uint32_t)(x >> 52) & 0x7FF) + 1) >> 11;
    return x & ((uint64_t)t - 1);
}

static inline fpr fpr_double(fpr x)
{
    x += (uint64_t)((((uint32_t)(x >> 52) & 0x7FF) + 0x7FF) >> 11) << 52;
    return x;
}

static fpr fpr_of(int64_t i)
{
    int s, e;
    uint32_t t;
    uint64_t m;

    s = (int)((uint64_t)i >> 63);
    i ^= -(int64_t)s;
    i += s;
    m = (uint64_t)i;
    e = 9;
    FPR_NORM64(m, e);
    m |= ((uint32_t)m & 0x1FF) + 0x1FF;
    m >>= 9;
    t = (uint32_t)((uint64_t)(i | -i) >> 63);
    m &= -(uint64_t)t;
    e &= -(int)t;
    return FPR(s, e, m);
}

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
    return (int64_t)xu;
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

static fpr fpr_add(fpr x, fpr y)
{
    uint64_t m, xu, yu, za;
    uint32_t cs;
    int ex, ey, sx, sy, cc;

    m = ((uint64_t)1 << 63) - 1;
    za = (x & m) - (y & m);
    cs = (uint32_t)(za >> 63) | ((1U - (uint32_t)(-za >> 63)) & (uint32_t)(x >> 63));
    m = (x ^ y) & -(uint64_t)cs;
    x ^= m;
    y ^= m;

    ex = (int)(x >> 52);
    sx = ex >> 11;
    ex &= 0x7FF;
    m = (uint64_t)(uint32_t)((ex + 0x7FF) >> 11) << 52;
    xu = ((x & (((uint64_t)1 << 52) - 1)) | m) << 3;
    ex -= 1078;

    ey = (int)(y >> 52);
    sy = ey >> 11;
    ey &= 0x7FF;
    m = (uint64_t)(uint32_t)((ey + 0x7FF) >> 11) << 52;
    yu = ((y & (((uint64_t)1 << 52) - 1)) | m) << 3;
    ey -= 1078;

    cc = ex - ey;
    yu &= -(uint64_t)((uint32_t)(cc - 60) >> 31);
    cc &= 63;

    m = fpr_ulsh(1, cc) - 1;
    yu |= (yu & m) + m;
    yu = fpr_ursh(yu, cc);

    xu += yu - ((yu << 1) & -(uint64_t)(sx ^ sy));
    FPR_NORM64(xu, ex);

    xu |= ((uint32_t)xu & 0x1FF) + 0x1FF;
    xu >>= 9;
    ex += 9;

    return FPR(sx, ex, xu);
}

static fpr fpr_mul(fpr x, fpr y)
{
    uint64_t xu, yu, w, zu, zv;
    uint32_t x0, x1, y0, y1, z0, z1, z2;
    int ex, ey, d, e, s;

    xu = (x & (((uint64_t)1 << 52) - 1)) | ((uint64_t)1 << 52);
    yu = (y & (((uint64_t)1 << 52) - 1)) | ((uint64_t)1 << 52);

    x0 = (uint32_t)xu & 0x01FFFFFF;
    x1 = (uint32_t)(xu >> 25);
    y0 = (uint32_t)yu & 0x01FFFFFF;
    y1 = (uint32_t)(yu >> 25);
    w = (uint64_t)x0 * (uint64_t)y0;
    z0 = (uint32_t)w & 0x01FFFFFF;
    z1 = (uint32_t)(w >> 25);
    w = (uint64_t)x0 * (uint64_t)y1;
    z1 += (uint32_t)w & 0x01FFFFFF;
    z2 = (uint32_t)(w >> 25);
    w = (uint64_t)x1 * (uint64_t)y0;
    z1 += (uint32_t)w & 0x01FFFFFF;
    z2 += (uint32_t)(w >> 25);
    zu = (uint64_t)x1 * (uint64_t)y1;
    z2 += (z1 >> 25);
    z1 &= 0x01FFFFFF;
    zu += z2;

    zu |= ((z0 | z1) + 0x01FFFFFF) >> 25;

    zv = (zu >> 1) | (zu & 1);
    w = zu >> 55;
    zu ^= (zu ^ zv) & -w;

    ex = (int)((x >> 52) & 0x7FF);
    ey = (int)((y >> 52) & 0x7FF);
    e = ex + ey - 2100 + (int)w;

    s = (int)((x ^ y) >> 63);
    d = ((ex + 0x7FF) & (ey + 0x7FF)) >> 11;
    zu &= -(uint64_t)d;

    return FPR(s, e, zu);
}

static uint64_t fpr_expm_p63(fpr x, fpr ccs)
{
    static const uint64_t C[] = {
        0x00000004741183A3u,
        0x00000036548CFC06u,
        0x0000024FDCBF140Au,
        0x0000171D939DE045u,
        0x0000D00CF58F6F84u,
        0x000680681CF796E3u,
        0x002D82D8305B0FEAu,
        0x011111110E066FD0u,
        0x0555555555070F00u,
        0x155555555581FF00u,
        0x400000000002B400u,
        0x7FFFFFFFFFFF4800u,
        0x8000000000000000u};
    const fpr fpr_ptwo63 = 0x43E0000000000000ULL;

    uint64_t z, y;
    unsigned u;
    uint32_t z0, z1, y0, y1;
    uint64_t a, b;

    y = C[0];
    z = (uint64_t)fpr_trunc(fpr_mul(x, fpr_ptwo63)) << 1;
    for (u = 1; u < 13; u++)
    {
        uint64_t c;
        z0 = (uint32_t)z;
        z1 = (uint32_t)(z >> 32);
        y0 = (uint32_t)y;
        y1 = (uint32_t)(y >> 32);
        a = ((uint64_t)z0 * (uint64_t)y1) + (((uint64_t)z0 * (uint64_t)y0) >> 32);
        b = ((uint64_t)z1 * (uint64_t)y0);
        c = (a >> 32) + (b >> 32);
        c += (((uint64_t)(uint32_t)a + (uint64_t)(uint32_t)b) >> 32);
        c += (uint64_t)z1 * (uint64_t)y1;
        y = C[u] - c;
    }

    z = (uint64_t)fpr_trunc(fpr_mul(ccs, fpr_ptwo63)) << 1;
    z0 = (uint32_t)z;
    z1 = (uint32_t)(z >> 32);
    y0 = (uint32_t)y;
    y1 = (uint32_t)(y >> 32);
    a = ((uint64_t)z0 * (uint64_t)y1) + (((uint64_t)z0 * (uint64_t)y0) >> 32);
    b = ((uint64_t)z1 * (uint64_t)y0);
    y = (a >> 32) + (b >> 32);
    y += (((uint64_t)(uint32_t)a + (uint64_t)(uint32_t)b) >> 32);
    y += (uint64_t)z1 * (uint64_t)y1;

    return y;
}

static fpr make_clean_fpr(uint64_t s, uint64_t e, uint64_t mant)
{
    if (e == 0)
        mant = 0;
    if (e >= 0x7FE)
        e = 0x7FD;
    return ((s & 1ULL) << 63) | ((e & 0x7FFULL) << 52) | (mant & ((1ULL << 52) - 1));
}

static fpr make_pos_lt1(uint64_t e, uint64_t mant)
{
    if (e == 0)
        return 0ULL;
    if (e > 1022)
        e = 1022;
    return (e << 52) | (mant & ((1ULL << 52) - 1));
}

int main(void)
{
    int i;

    // 1. test_lt.txt (10,000 cases)
    FILE *f_lt = fopen("test_lt.txt", "w");
    for (i = 0; i < 10000; i++)
    {
        fpr x = rand64();
        fpr y = rand64();
        if (i < 4)
        {
            x = (uint64_t)(i & 1) << 63;
            y = (uint64_t)((i >> 1) & 1) << 63;
        }
        else if (i % 5 == 0)
        {
            x |= (1ULL << 63);
            y |= (1ULL << 63);
        }
        else if (i % 5 == 1)
        {
            y = x ^ (1ULL << 63);
        }
        else if (i % 5 == 2)
        {
            y = x;
        }
        fprintf(f_lt, "%016llx %016llx %x\n",
                (unsigned long long)x, (unsigned long long)y, (unsigned)fpr_lt(x, y));
    }
    fclose(f_lt);

    // 2. test_pack.txt (10,000 cases)
    FILE *f_pack = fopen("test_pack.txt", "w");
    for (i = 0; i < 10000; i++)
    {
        int s = (int)(rand64() & 1);
        int e = (i % 4 == 0) ? (-1080 + (int)(rand64() % 10))
                             : ((int)(rand64() % 2100) - 1100);
        uint64_t m = rand64() & 0x007FFFFFFFFFFFFFULL;
        if (i % 3 != 0)
            m |= (1ULL << 54);
        fpr z = FPR(s, e, m);
        fprintf(f_pack, "%x %08x %016llx %016llx\n",
                (unsigned)s, (uint32_t)e, (unsigned long long)m, (unsigned long long)z);
    }
    fclose(f_pack);

    // 3. test_round.txt (10,000 cases: fpr_trunc, fpr_floor, fpr_rint)
    FILE *f_round = fopen("test_round.txt", "w");
    for (i = 0; i < 10000; i++)
    {
        fpr x;
        if (i < 4)
        {
            x = (uint64_t)(i & 1) << 63;
        }
        else if (i % 2 == 0)
        {
            uint64_t e_test = 1020 + (rand64() % 66); // [1020..1085]
            x = make_clean_fpr(rand64() & 1, e_test, rand64());
        }
        else
        {
            uint64_t e_test = rand64() % 1086; // [0..1085]
            x = make_clean_fpr(rand64() & 1, e_test, rand64());
        }
        fprintf(f_round, "%016llx %016llx %016llx %016llx\n",
                (unsigned long long)x,
                (unsigned long long)(uint64_t)fpr_trunc(x),
                (unsigned long long)(uint64_t)fpr_floor(x),
                (unsigned long long)(uint64_t)fpr_rint(x));
    }
    fclose(f_round);

    // 4. test_unary.txt (10,000 cases: fpr_of, fpr_half, fpr_double, fpr_neg)
    FILE *f_unary = fopen("test_unary.txt", "w");
    for (i = 0; i < 10000; i++)
    {
        int64_t iv;
        if (i == 0)
            iv = 0;
        else if (i == 1)
            iv = 1;
        else if (i == 2)
            iv = -1;
        else if (i == 3)
            iv = 0x7FFFFFFFFFFFFFFFLL;
        else if (i == 4)
            iv = -0x7FFFFFFFFFFFFFFFLL;
        else if (i % 4 == 0)
            iv = (int64_t)(rand64() >> 1);
        else if (i % 4 == 1)
            iv = -(int64_t)(rand64() >> 1);
        else if (i % 4 == 2)
            iv = (int32_t)rand64();
        else
            iv = (int16_t)rand64();

        fpr x;
        if (i == 0)
            x = 0x0000000000000000ULL;
        else if (i == 1)
            x = 0x8000000000000000ULL;
        else if (i == 2)
            x = 0x3FF0000000000000ULL;
        else if (i == 3)
            x = 0xBFF0000000000000ULL;
        else
            x = make_clean_fpr(rand64() & 1, 2 + (rand64() % 2040), rand64());

        fprintf(f_unary, "%016llx %016llx %016llx %016llx %016llx %016llx\n",
                (unsigned long long)(uint64_t)iv,
                (unsigned long long)x,
                (unsigned long long)fpr_of(iv),
                (unsigned long long)fpr_half(x),
                (unsigned long long)fpr_double(x),
                (unsigned long long)fpr_neg(x));
    }
    fclose(f_unary);

    // 5. test_add.txt (20,000 cases: 20 directed + 19,980 targeted random)
    FILE *f_add = fopen("test_add.txt", "w");
    const fpr add_dir[20][2] = {
        {0x0000000000000000ULL, 0x0000000000000000ULL},
        {0x8000000000000000ULL, 0x0000000000000000ULL},
        {0x0000000000000000ULL, 0x8000000000000000ULL},
        {0x8000000000000000ULL, 0x8000000000000000ULL},
        {0x3FF0000000000000ULL, 0xBFF0000000000000ULL},
        {0xBFF0000000000000ULL, 0x3FF0000000000000ULL},
        {0x3FF0000000000000ULL, 0x8000000000000000ULL},
        {0x8000000000000000ULL, 0xBFF0000000000000ULL},
        {0x3FF0000000000000ULL, 0x3CA0000000000000ULL},
        {0x3FF0000000000001ULL, 0x3CA0000000000000ULL},
        {0x3FF0000000000000ULL, 0x3CA0000000000001ULL},
        {0x3FFFFFFFFFFFFFFFULL, 0x3CA0000000000000ULL},
        {0x3FF0000000000000ULL, 0x3C50000000000000ULL},
        {0x3FF0000000000000ULL, 0x3C40000000000000ULL},
        {0x3FF0000000000000ULL, 0x3C30000000000000ULL},
        {0x3FF0000000000000ULL, 0xBC40000000000000ULL},
        {0x3FF0000000000000ULL, 0xBC30000000000000ULL},
        {0x3FF0000000000001ULL, 0xBFF0000000000000ULL},
        {0x0010000000000001ULL, 0x8010000000000000ULL},
        {0x8010000000000001ULL, 0x0010000000000000ULL}};
    for (i = 0; i < 20; i++)
    {
        fprintf(f_add, "%016llx %016llx %016llx\n",
                (unsigned long long)add_dir[i][0],
                (unsigned long long)add_dir[i][1],
                (unsigned long long)fpr_add(add_dir[i][0], add_dir[i][1]));
    }
    for (i = 20; i < 20000; i++)
    {
        fpr x, y;
        int b = i % 5;
        if (b == 0)
        {
            uint64_t ex = 800 + (rand64() % 400);
            uint64_t diff = (uint64_t)(i % 66);
            uint64_t ey = (ex > diff) ? (ex - diff) : 0;
            x = make_clean_fpr(rand64() & 1, ex, rand64());
            y = make_clean_fpr(rand64() & 1, ey, rand64());
        }
        else if (b == 1)
        {
            uint64_t ex = 900 + (rand64() % 250);
            uint64_t m1 = rand64() & ((1ULL << 52) - 1);
            int cb = 1 + (int)(rand64() % 52);
            uint64_t delta = rand64() & ((1ULL << (53 - cb)) - 1);
            uint64_t m2 = (m1 ^ delta) & ((1ULL << 52) - 1);
            uint64_t sx = rand64() & 1;
            x = make_clean_fpr(sx, ex, m1);
            y = make_clean_fpr(sx ^ 1, ex, m2);
        }
        else if (b == 2)
        {
            if (i % 10 == 0)
            {
                x = (rand64() & 1) << 63;
                y = (rand64() & 1) << 63;
            }
            else
            {
                x = make_clean_fpr(rand64() & 1, 1 + (rand64() % 2040), rand64());
                y = fpr_neg(x);
            }
        }
        else if (b == 3)
        {
            uint64_t ex = 950 + (rand64() % 150);
            uint64_t m1 = (rand64() & 1) ? 0x000FFFFFFFFFFFFFULL : (rand64() & ~3ULL);
            uint64_t m2 = (rand64() & 1) ? 0ULL : (1ULL << 51);
            x = make_clean_fpr(rand64() & 1, ex, m1);
            y = make_clean_fpr(rand64() & 1, ex - 53, m2);
        }
        else
        {
            uint64_t ex = (i % 10 < 4) ? (1 + (rand64() % 8)) : (1 + (rand64() % 2040));
            uint64_t ey = (i % 10 < 4) ? (1 + (rand64() % 8)) : (1 + (rand64() % 2040));
            x = make_clean_fpr(rand64() & 1, ex, rand64());
            y = make_clean_fpr(rand64() & 1, ey, rand64());
        }
        if (i & 1)
        {
            fpr tmp = x;
            x = y;
            y = tmp;
        }
        fprintf(f_add, "%016llx %016llx %016llx\n",
                (unsigned long long)x, (unsigned long long)y,
                (unsigned long long)fpr_add(x, y));
    }
    fclose(f_add);

    // 6. test_mul.txt (20,000 cases: 16 directed + 19,984 targeted random)
    FILE *f_mul = fopen("test_mul.txt", "w");
    const fpr mul_dir[16][2] = {
        {0x0000000000000000ULL, 0x3FF0000000000000ULL},
        {0x0000000000000000ULL, 0xBFF0000000000000ULL},
        {0x8000000000000000ULL, 0xBFF0000000000000ULL},
        {0x8000000000000000ULL, 0x0000000000000000ULL},
        {0x3FF0000000000000ULL, 0x3FF0000000000000ULL},
        {0x3FF8000000000000ULL, 0x3FF8000000000000ULL},
        {0x3FF0000000000001ULL, 0x3FF0000000000001ULL},
        {0x3FFFFFFFFFFFFFFFULL, 0x3FFFFFFFFFFFFFFFULL},
        {0x3FF0000000000001ULL, 0x3FF8000000000000ULL},
        {0x3FF0000000000003ULL, 0x3FF8000000000000ULL},
        {0x3FF6A09E667F3BCDULL, 0x3FF6A09E667F3BCDULL},
        {0x3FF6A09E667F3BCCULL, 0x3FF6A09E667F3BCCULL},
        {0x1FF0000000000000ULL, 0x2000000000000000ULL},
        {0x1FF8000000000000ULL, 0x2008000000000000ULL},
        {0x9FF0000000000000ULL, 0x2000000000000000ULL},
        {0x3FE0000000000000ULL, 0xBFE0000000000000ULL}};
    for (i = 0; i < 16; i++)
    {
        fprintf(f_mul, "%016llx %016llx %016llx\n",
                (unsigned long long)mul_dir[i][0],
                (unsigned long long)mul_dir[i][1],
                (unsigned long long)fpr_mul(mul_dir[i][0], mul_dir[i][1]));
    }
    for (i = 16; i < 20000; i++)
    {
        fpr x, y;
        int b = i % 4;
        if (b == 0)
        {
            uint64_t sum_e = 1020 + (rand64() % 9);
            uint64_t ex = 1 + (rand64() % (sum_e - 1));
            x = make_clean_fpr(rand64() & 1, ex, rand64());
            y = make_clean_fpr(rand64() & 1, sum_e - ex, rand64());
        }
        else if (b == 1)
        {
            uint64_t ex = 520 + (rand64() % 1000);
            uint64_t mant = (i % 8 == 1) ? (0x0006A09E667F3BC0ULL + (rand64() & 0x1F)) : rand64();
            x = make_clean_fpr(rand64() & 1, ex, mant);
            y = (i % 8 == 5) ? x : make_clean_fpr(rand64() & 1, 520 + (rand64() % 1000), mant);
        }
        else if (b == 2)
        {
            uint64_t ex = 700 + (rand64() % 700);
            uint64_t ey = 700 + (rand64() % 700);
            uint64_t m1 = (rand64() & 1) ? 0x000FFFFFFFFFFFFFULL : (rand64() & 0x000FFFFF00000000ULL);
            uint64_t m2 = (rand64() & 1) ? (rand64() & 0x000FFFFF00000003ULL) : rand64();
            x = make_clean_fpr(rand64() & 1, ex, m1);
            y = make_clean_fpr(rand64() & 1, ey, m2);
        }
        else
        {
            if (i % 20 == 3)
            {
                x = (rand64() & 1) << 63;
                y = make_clean_fpr(rand64() & 1, 1 + (rand64() % 2040), rand64());
            }
            else
            {
                x = make_clean_fpr(rand64() & 1, 1 + (rand64() % 1530), rand64());
                y = make_clean_fpr(rand64() & 1, 1 + (rand64() % 1530), rand64());
            }
        }
        if (i & 1)
        {
            fpr tmp = x;
            x = y;
            y = tmp;
        }
        fprintf(f_mul, "%016llx %016llx %016llx\n",
                (unsigned long long)x, (unsigned long long)y,
                (unsigned long long)fpr_mul(x, y));
    }
    fclose(f_mul);

    // 7. test_expm_p63.txt (5,000 cases: 10 directed + 4,990 targeted random)
    FILE *f_expm = fopen("test_expm_p63.txt", "w");
    const fpr expm_dir[10][2] = {
        {0x0000000000000000ULL, 0x3FEFFFFFFFFFFFFFULL},
        {0x0000000000000000ULL, 0x0000000000000000ULL},
        {0x3FE62E42FEFA39EFULL, 0x3FEFFFFFFFFFFFFFULL},
        {0x3FE62E42FEFA39EFULL, 0x3FE6666666666666ULL},
        {0x3FE0000000000000ULL, 0x3FE8000000000000ULL},
        {0x3FD0000000000000ULL, 0x3FEFFFFFFFFFFFFFULL},
        {0x3CB0000000000000ULL, 0x3FE8000000000000ULL},
        {0x3C00000000000000ULL, 0x3FE8000000000000ULL},
        {0x3BF0000000000000ULL, 0x3FE8000000000000ULL},
        {0x3FE62E42FEFA39EEULL, 0x0000000000000000ULL}};
    for (i = 0; i < 10; i++)
    {
        fprintf(f_expm, "%016llx %016llx %016llx\n",
                (unsigned long long)expm_dir[i][0],
                (unsigned long long)expm_dir[i][1],
                (unsigned long long)fpr_expm_p63(expm_dir[i][0], expm_dir[i][1]));
    }
    const fpr LN2_BITS = 0x3FE62E42FEFA39EFULL;
    for (i = 10; i < 5000; i++)
    {
        fpr x, ccs;
        if (i % 4 == 0)
        {
            x = make_pos_lt1(1015 + (rand64() % 8), rand64());
            if (x > LN2_BITS)
                x = (1022ULL << 52) | (rand64() % (LN2_BITS & ((1ULL << 52) - 1)));
            ccs = make_pos_lt1(1022, rand64());
        }
        else if (i % 4 == 1)
        {
            x = make_pos_lt1(955 + (rand64() % 60), rand64());
            ccs = make_pos_lt1(1020 + (rand64() % 3), rand64());
        }
        else if (i % 4 == 2)
        {
            x = LN2_BITS - (rand64() & 0xFFFFULL);
            ccs = 0x3FEFFFFFFFFFFFFFULL - (rand64() & 0xFFFFULL);
        }
        else
        {
            uint64_t ex = (i % 20 == 3) ? 0 : (900 + (rand64() % 123));
            x = make_pos_lt1(ex, rand64());
            if (x > LN2_BITS)
                x &= ~(1ULL << 51);
            ccs = make_pos_lt1((i % 20 == 7) ? 0 : (950 + (rand64() % 73)), rand64());
        }
        fprintf(f_expm, "%016llx %016llx %016llx\n",
                (unsigned long long)x, (unsigned long long)ccs,
                (unsigned long long)fpr_expm_p63(x, ccs));
    }
    fclose(f_expm);

    printf("[OK] Generated 85,000 deterministic vectors across 7 files for all 12 fpr modules.\n");
    return 0;
}