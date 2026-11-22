/*
 * Wrapper for implementing the NIST API for the PQC standardization
 * process.
 */

#include <stddef.h>
#include <string.h>

#include "api.h"
#include "inner.h"
#include <stdio.h>
#include <time.h>
#include <x86intrin.h>
#define NONCELEN 40

/*
 * If stack usage is an issue, define TEMPALLOC to static in order to
 * allocate temporaries in the data section instead of the stack. This
 * would make the crypto_sign_keypair(), crypto_sign(), and
 * crypto_sign_open() functions not reentrant and not thread-safe, so
 * this should be done only for testing purposes.
 */
#define TEMPALLOC

void randombytes_init(unsigned char *entropy_input,
					  unsigned char *personalization_string,
					  int security_strength);
int randombytes(unsigned char *x, unsigned long long xlen);

int crypto_sign_keypair(unsigned char *pk, unsigned char *sk)
{
	TEMPALLOC union
	{
		uint8_t b[FALCON_KEYGEN_TEMP_9];
		uint64_t dummy_u64;
		fpr dummy_fpr;
	} tmp;
	TEMPALLOC int8_t f[512], g[512], F[512];
	TEMPALLOC uint16_t h[512];
	TEMPALLOC unsigned char seed[48];
	TEMPALLOC inner_shake256_context rng;
	size_t u, v;

	/*
	 * Generate key pair.
	 */
	randombytes(seed, sizeof seed);
	inner_shake256_init(&rng);
	inner_shake256_inject(&rng, seed, sizeof seed);
	inner_shake256_flip(&rng);
	Zf(keygen)(&rng, f, g, F, NULL, h, 9, tmp.b);

	/*
	 * Encode private key.
	 */
	sk[0] = 0x50 + 9;
	u = 1;
	v = Zf(trim_i8_encode)(sk + u, CRYPTO_SECRETKEYBYTES - u,
						   f, 9, Zf(max_fg_bits)[9]);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	v = Zf(trim_i8_encode)(sk + u, CRYPTO_SECRETKEYBYTES - u,
						   g, 9, Zf(max_fg_bits)[9]);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	v = Zf(trim_i8_encode)(sk + u, CRYPTO_SECRETKEYBYTES - u,
						   F, 9, Zf(max_FG_bits)[9]);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	if (u != CRYPTO_SECRETKEYBYTES)
	{
		return -1;
	}

	/*
	 * Encode public key.
	 */
	pk[0] = 0x00 + 9;
	v = Zf(modq_encode)(pk + 1, CRYPTO_PUBLICKEYBYTES - 1, h, 9);
	if (v != CRYPTO_PUBLICKEYBYTES - 1)
	{
		return -1;
	}

	return 0;
}

int crypto_sign(unsigned char *sm, unsigned long long *smlen,
				const unsigned char *m, unsigned long long mlen,
				const unsigned char *sk)
{
	TEMPALLOC union
	{
		uint8_t b[72 * 512];
		uint64_t dummy_u64;
		fpr dummy_fpr;
	} tmp;
	TEMPALLOC int8_t f[512], g[512], F[512], G[512];
	TEMPALLOC union
	{
		int16_t sig[512];
		uint16_t hm[512];
	} r;
	TEMPALLOC unsigned char seed[48], nonce[NONCELEN];
	TEMPALLOC unsigned char esig[CRYPTO_BYTES - 2 - sizeof nonce];
	TEMPALLOC inner_shake256_context sc;
	size_t u, v, sig_len;

	/*
	 * Decode the private key.
	 */
	if (sk[0] != 0x50 + 9)
	{
		return -1;
	}
	u = 1;
	v = Zf(trim_i8_decode)(f, 9, Zf(max_fg_bits)[9],
						   sk + u, CRYPTO_SECRETKEYBYTES - u);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	v = Zf(trim_i8_decode)(g, 9, Zf(max_fg_bits)[9],
						   sk + u, CRYPTO_SECRETKEYBYTES - u);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	v = Zf(trim_i8_decode)(F, 9, Zf(max_FG_bits)[9],
						   sk + u, CRYPTO_SECRETKEYBYTES - u);
	if (v == 0)
	{
		return -1;
	}
	u += v;
	if (u != CRYPTO_SECRETKEYBYTES)
	{
		return -1;
	}
	if (!Zf(complete_private)(G, f, g, F, 9, tmp.b))
	{
		return -1;
	}

	/*
	 * Create a random nonce (40 bytes).
	 */
	randombytes(nonce, sizeof nonce);

	/*
	 * Hash message nonce + message into a vector.
	 */
	inner_shake256_init(&sc);
	inner_shake256_inject(&sc, nonce, sizeof nonce);
	inner_shake256_inject(&sc, m, mlen);
	inner_shake256_flip(&sc);
	Zf(hash_to_point_vartime)(&sc, r.hm, 9);

	/*
	 * Initialize a RNG.
	 */
	randombytes(seed, sizeof seed);
	inner_shake256_init(&sc);
	inner_shake256_inject(&sc, seed, sizeof seed);
	inner_shake256_flip(&sc);

	/*
	 * Compute the signature.
	 */
	Zf(sign_dyn)(r.sig, &sc, f, g, F, G, r.hm, 9, tmp.b);

	/*
	 * Encode the signature and bundle it with the message. Format is:
	 *   signature length     2 bytes, big-endian
	 *   nonce                40 bytes
	 *   message              mlen bytes
	 *   signature            slen bytes
	 */
	esig[0] = 0x20 + 9;
	sig_len = Zf(comp_encode)(esig + 1, (sizeof esig) - 1, r.sig, 9);
	if (sig_len == 0)
	{
		return -1;
	}
	sig_len++;
	memmove(sm + 2 + sizeof nonce, m, mlen);
	sm[0] = (unsigned char)(sig_len >> 8);
	sm[1] = (unsigned char)sig_len;
	memcpy(sm + 2, nonce, sizeof nonce);
	memcpy(sm + 2 + (sizeof nonce) + mlen, esig, sig_len);
	*smlen = 2 + (sizeof nonce) + mlen + sig_len;
	return 0;
}

int crypto_sign_open(unsigned char *m, unsigned long long *mlen,
					 const unsigned char *sm, unsigned long long smlen,
					 const unsigned char *pk)
{
	TEMPALLOC union
	{
		uint8_t b[2 * 512];
		uint64_t dummy_u64;
		fpr dummy_fpr;
	} tmp;
	const unsigned char *esig;
	TEMPALLOC uint16_t h[512], hm[512];
	TEMPALLOC int16_t sig[512];
	TEMPALLOC inner_shake256_context sc;
	size_t sig_len, msg_len;

	/*
	 * Decode public key.
	 */
	if (pk[0] != 0x00 + 9)
	{
		return -1;
	}
	if (Zf(modq_decode)(h, 9, pk + 1, CRYPTO_PUBLICKEYBYTES - 1) != CRYPTO_PUBLICKEYBYTES - 1)
	{
		return -1;
	}
	Zf(to_ntt_monty)(h, 9);

	/*
	 * Find nonce, signature, message length.
	 */
	if (smlen < 2 + NONCELEN)
	{
		return -1;
	}
	sig_len = ((size_t)sm[0] << 8) | (size_t)sm[1];
	if (sig_len > (smlen - 2 - NONCELEN))
	{
		return -1;
	}
	msg_len = smlen - 2 - NONCELEN - sig_len;

	/*
	 * Decode signature.
	 */
	esig = sm + 2 + NONCELEN + msg_len;
	if (sig_len < 1 || esig[0] != 0x20 + 9)
	{
		return -1;
	}
	if (Zf(comp_decode)(sig, 9,
						esig + 1, sig_len - 1) != sig_len - 1)
	{
		return -1;
	}
	/*
	 * Hash nonce + message into a vector.
	 */
	inner_shake256_init(&sc);
	inner_shake256_inject(&sc, sm + 2, NONCELEN + msg_len);
	inner_shake256_flip(&sc);
	Zf(hash_to_point_vartime)(&sc, hm, 9);

	/*
	 * Verify signature.
	 */
	if (!Zf(verify_raw)(hm, sig, h, 9, tmp.b))
	{
		return -1;
	}
	{
		static int dump_cnt = 0;
		if (dump_cnt == 2)
		{
			size_t comp_len = sig_len - 1;
			const int16_t *s1_neg = (const int16_t *)tmp.b; // verify_raw lưu sẵn -s1 trong tmp.b
			uint32_t s = 0, ng = 0;

			// 1. INPUTS (3 file)
			FILE *f_pk = fopen("tb_pk.txt", "w");
			FILE *f_sig = fopen("tb_sig_comp.txt", "w");
			FILE *f_c0 = fopen("tb_c0.txt", "w");

			// 2. GOLDEN EXPECTED (4 file)
			FILE *f_hntt = fopen("tb_exp_h_ntt.txt", "w");
			FILE *f_s2 = fopen("tb_exp_s2.txt", "w");
			FILE *f_s1 = fopen("tb_exp_s1.txt", "w");
			FILE *f_norm = fopen("tb_exp_norm.txt", "w");

			for (size_t i = 0; i < CRYPTO_PUBLICKEYBYTES; i++)
			{
				fprintf(f_pk, "%02X\n", pk[i]);
			}
			for (size_t i = 0; i < 625; i++)
			{
				uint8_t b = (i < comp_len) ? esig[1 + i] : 0x00;
				fprintf(f_sig, "%02X\n", b);
			}
			for (int i = 0; i < 512; i++)
			{
				int32_t z1 = s1_neg[i];
				int32_t z2 = sig[i];
				s += (uint32_t)(z1 * z1);
				ng |= s;
				s += (uint32_t)(z2 * z2);
				ng |= s;

				fprintf(f_c0, "%04X\n", hm[i]);
				fprintf(f_hntt, "%04X\n", h[i]);
				fprintf(f_s2, "%04X\n", (uint16_t)sig[i]);
				fprintf(f_s1, "%04X\n", (uint16_t)s1_neg[i]);
			}
			s |= -(ng >> 31);
			fprintf(f_norm, "%08X\n", s);

			fclose(f_pk);
			fclose(f_sig);
			fclose(f_c0);
			fclose(f_hntt);
			fclose(f_s2);
			fclose(f_s1);
			fclose(f_norm);

			printf("[DUMP OK] comp_len=%zu | norm=0x%08X\n", comp_len, s);
		}
		dump_cnt++;
	}
	/*
	 * Return plaintext.
	 */
	memmove(m, sm + 2 + NONCELEN, msg_len);
	*mlen = msg_len;
	return 0;
}
