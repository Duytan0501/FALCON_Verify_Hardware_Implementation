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

    printf("Dump thanh cong test_lt.txt va test_pack.txt!\n");
    return 0;
}