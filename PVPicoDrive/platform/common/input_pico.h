#ifndef INCLUDE_c48097f3ff2a6a9af1cce8fd7a9b3f0c
#define INCLUDE_c48097f3ff2a6a9af1cce8fd7a9b3f0c 1

/* gamepad - MXYZ SACB RLDU */
#define GBTN_UP         0
#define GBTN_DOWN       1
#define GBTN_LEFT       2
#define GBTN_RIGHT      3
#define GBTN_B          4
#define GBTN_C          5
#define GBTN_A          6
#define GBTN_START      7
#define GBTN_Z          8
#define GBTN_Y          9
#define GBTN_X          10
#define GBTN_MODE       11

/* ui events */
#define PEVB_VOL_DOWN   30
#define PEVB_VOL_UP     29
#define PEVB_STATE_LOAD 28
#define PEVB_STATE_SAVE 27
#define PEVB_SWITCH_RND 26
#define PEVB_SSLOT_PREV 25
#define PEVB_SSLOT_NEXT 24
#define PEVB_MENU       23
#define PEVB_FF         22
#define PEVB_PICO_PNEXT 21
#define PEVB_PICO_PPREV 20
#define PEVB_PICO_SWINP 19

#define PEV_VOL_DOWN    (1 << PEVB_VOL_DOWN)
#define PEV_VOL_UP      (1 << PEVB_VOL_UP)
#define PEV_STATE_LOAD  (1 << PEVB_STATE_LOAD)
#define PEV_STATE_SAVE  (1 << PEVB_STATE_SAVE)
#define PEV_SWITCH_RND  (1 << PEVB_SWITCH_RND)
#define PEV_SSLOT_PREV  (1 << PEVB_SSLOT_PREV)
#define PEV_SSLOT_NEXT  (1 << PEVB_SSLOT_NEXT)
#define PEV_MENU        (1 << PEVB_MENU)
#define PEV_FF          (1 << PEVB_FF)
#define PEV_PICO_PNEXT  (1 << PEVB_PICO_PNEXT)
#define PEV_PICO_PPREV  (1 << PEVB_PICO_PPREV)
#define PEV_PICO_SWINP  (1 << PEVB_PICO_SWINP)

#define PEV_MASK 0x7ff80000

#endif /* INCLUDE_c48097f3ff2a6a9af1cce8fd7a9b3f0c */
