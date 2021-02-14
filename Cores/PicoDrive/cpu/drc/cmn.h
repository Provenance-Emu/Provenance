typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef signed short   s16;
typedef unsigned int   u32;
typedef signed int     s32;

#define DRC_TCACHE_SIZE         (2*1024*1024)

extern u8 *tcache;

void drc_cmn_init(void);
void drc_cmn_cleanup(void);

