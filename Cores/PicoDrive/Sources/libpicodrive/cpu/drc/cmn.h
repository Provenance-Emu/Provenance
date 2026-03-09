
#define DRC_TCACHE_SIZE         (4*1024*1024)

extern u8 *tcache;

void drc_cmn_init(void);
void drc_cmn_cleanup(void);

#define BITMASK1(v0) (1 << (v0))
#define BITMASK2(v0,v1) ((1 << (v0)) | (1 << (v1)))
#define BITMASK3(v0,v1,v2) (BITMASK2(v0,v1) | (1 << (v2)))
#define BITMASK4(v0,v1,v2,v3) (BITMASK3(v0,v1,v2) | (1 << (v3)))
#define BITMASK5(v0,v1,v2,v3,v4) (BITMASK4(v0,v1,v2,v3) | (1 << (v4)))
#define BITMASK6(v0,v1,v2,v3,v4,v5) (BITMASK5(v0,v1,v2,v3,v4) | (1 << (v5)))
#define BITRANGE(v0,v1) (BITMASK1(v1+1)-BITMASK1(v0)) // set with v0..v1

// binary search approach, since we don't have CLZ on ARM920T
#define FOR_ALL_BITS_SET_DO(mask, bit, code) { \
  u32 __mask = mask; \
  for (bit = 0; bit < 32 && mask; bit++, __mask >>= 1) { \
    if (!(__mask & 0xffff)) \
      bit += 16,__mask >>= 16; \
    if (!(__mask & 0xff)) \
      bit += 8, __mask >>= 8; \
    if (!(__mask & 0xf)) \
      bit += 4, __mask >>= 4; \
    if (!(__mask & 0x3)) \
      bit += 2, __mask >>= 2; \
    if (!(__mask & 0x1)) \
      bit += 1, __mask >>= 1; \
    if (__mask & 0x1) { \
      code; \
    } \
  } \
}

// inspired by https://graphics.stanford.edu/~seander/bithacks.html
static inline int count_bits(unsigned val)
{
       val = val - ((val >> 1) & 0x55555555);
       val = (val & 0x33333333) + ((val >> 2) & 0x33333333);
       return (((val + (val >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
}

