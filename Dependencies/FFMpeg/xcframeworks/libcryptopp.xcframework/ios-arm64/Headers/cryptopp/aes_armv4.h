/* Header file for use with Cryptogam's ARMv4 AES.         */
/* Also see http://www.openssl.org/~appro/cryptogams/ and  */
/* https://wiki.openssl.org/index.php?title=Cryptogams_AES */

#ifndef CRYPTOGAMS_AES_ARMV4_H
#define CRYPTOGAMS_AES_ARMV4_H

#ifdef __cplusplus
extern "C" {
#endif

//#define AES_MAXNR 14
//typedef struct AES_KEY_st {
//    unsigned int rd_key[4 * (AES_MAXNR + 1)];
//    int rounds;
//} AES_KEY;

// Instead of AES_KEY we use a 'word32 rkey[4*15+4]'. It has space for
// both the AES_MAXNR round keys and the number of rounds in the tail.

int cryptogams_AES_set_encrypt_key(const unsigned char *userKey, const int bits, unsigned int *rkey);
int cryptogams_AES_set_decrypt_key(const unsigned char *userKey, const int bits, unsigned int *rkey);
void cryptogams_AES_encrypt_block(const unsigned char *in, unsigned char *out, const unsigned int *rkey);
void cryptogams_AES_decrypt_block(const unsigned char *in, unsigned char *out, const unsigned int *rkey);

#ifdef __cplusplus
}
#endif

#endif  /* CRYPTOGAMS_AES_ARMV4_H */
