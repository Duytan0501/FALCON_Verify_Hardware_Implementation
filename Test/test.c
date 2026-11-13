#include <stdio.h>
#include <string.h>
#include "api.h"

int main() {
    unsigned char pk[CRYPTO_PUBLICKEYBYTES];
    unsigned char sk[CRYPTO_SECRETKEYBYTES];
    unsigned char msg[] = "Hello Falcon Hardware Test!";
    unsigned long long mlen = strlen((char*)msg);
    unsigned char sm[CRYPTO_BYTES + 100]; // Chứa chữ ký + tin nhắn
    unsigned long long smlen;

    printf("Key Pair\n");
    crypto_sign_keypair(pk, sk);

    printf("Sign\n");
    crypto_sign(sm, &smlen, msg, mlen, sk);

    printf("Verify\n");
    unsigned char msg_out[100];
    unsigned long long mlen_out;
    int ret = crypto_sign_open(msg_out, &mlen_out, sm, smlen, pk);
    if (ret == 0) {
        printf("-> XÁC THỰC THÀNH CÔNG TẠI MAIN!\n");
    } else {
        printf("-> XÁC THỰC THẤT BẠI TẠI MAIN!\n");
    }

    return 0;
}