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
#define PEVB_PICO_STORY 19
#define PEVB_PICO_PAD   18
#define PEVB_PICO_PENST 17
#define PEVB_SWITCH_KBD 16
#define PEVB_RESET      15

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
#define PEV_PICO_STORY  (1 << PEVB_PICO_STORY)
#define PEV_PICO_PAD    (1 << PEVB_PICO_PAD)
#define PEV_PICO_PENST  (1 << PEVB_PICO_PENST)
#define PEV_SWITCH_KBD  (1 << PEVB_SWITCH_KBD)
#define PEV_RESET       (1 << PEVB_RESET)

#define PEV_MASK 0x7fff8000

/* Keyboard Pico */

// Blue buttons
#define PEVB_KBD_1 0x16
#define PEVB_KBD_2 0x1e
#define PEVB_KBD_3 0x26
#define PEVB_KBD_4 0x25
#define PEVB_KBD_5 0x2e
#define PEVB_KBD_6 0x36
#define PEVB_KBD_7 0x3d
#define PEVB_KBD_8 0x3e
#define PEVB_KBD_9 0x46
#define PEVB_KBD_0 0x45
#define PEVB_KBD_MINUS 0x4e
#define PEVB_KBD_CARET 0x55
#define PEVB_KBD_YEN 0x6a // ￥

#define PEVB_KBD_q 0x15
#define PEVB_KBD_w 0x1d
#define PEVB_KBD_e 0x24
#define PEVB_KBD_r 0x2d
#define PEVB_KBD_t 0x2c
#define PEVB_KBD_y 0x35
#define PEVB_KBD_u 0x3c
#define PEVB_KBD_i 0x43
#define PEVB_KBD_o 0x44
#define PEVB_KBD_p 0x4d
#define PEVB_KBD_AT 0x54
#define PEVB_KBD_LEFTBRACKET 0x5b

#define PEVB_KBD_a 0x1c
#define PEVB_KBD_s 0x1b
#define PEVB_KBD_d 0x23
#define PEVB_KBD_f 0x2b
#define PEVB_KBD_g 0x34
#define PEVB_KBD_h 0x33
#define PEVB_KBD_j 0x3b
#define PEVB_KBD_k 0x42
#define PEVB_KBD_l 0x4b
#define PEVB_KBD_SEMICOLON 0x4c
#define PEVB_KBD_COLON 0x52
#define PEVB_KBD_RIGHTBRACKET 0x5d

#define PEVB_KBD_z 0x1a
#define PEVB_KBD_x 0x22
#define PEVB_KBD_c 0x21
#define PEVB_KBD_v 0x2a
#define PEVB_KBD_b 0x32
#define PEVB_KBD_n 0x31
#define PEVB_KBD_m 0x3a
#define PEVB_KBD_COMMA 0x41
#define PEVB_KBD_PERIOD 0x49
#define PEVB_KBD_SLASH 0x4a
#define PEVB_KBD_RO 0x51 // ろ

#define PEVB_KBD_SPACE 0x29

// Green button on top-left
#define PEVB_KBD_ESCAPE 0x76

// Orange buttons on left
#define PEVB_KBD_CAPSLOCK 0x58
#define PEVB_KBD_LSHIFT 0x12 // left shift

// Green buttons on right
#define PEVB_KBD_BACKSPACE 0x66
#define PEVB_KBD_INSERT 0x81
#define PEVB_KBD_DELETE 0x85

// Red button on bottom-right
#define PEVB_KBD_RETURN 0x5a

// Orange buttons on bottom
#define PEVB_KBD_SOUND 0x67 // muhenkan (graph)
#define PEVB_KBD_HOME 0x64 // henkan (clr/home)
#define PEVB_KBD_CJK 0x13 // kana/kanji
#define PEVB_KBD_ROMAJI 0x17

// Other buttons for SC-3000
#define PEVB_KBD_RSHIFT 0x59 // right shift
#define PEVB_KBD_CTRL 0x14
#define PEVB_KBD_FUNC 0x11
#define PEVB_KBD_UP 0x75
#define PEVB_KBD_DOWN 0x72
#define PEVB_KBD_LEFT 0x6b
#define PEVB_KBD_RIGHT 0x74

#endif /* INCLUDE_c48097f3ff2a6a9af1cce8fd7a9b3f0c */
