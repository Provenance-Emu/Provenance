#pragma once

extern void* x11_glc;
extern void input_x11_init();
extern void input_x11_handle();
extern void event_x11_handle();
extern void x11_window_create();
extern void x11_window_set_text(const char* text);
extern void x11_window_destroy();

// numbers
const int KEY_1		=  10;
const int KEY_2		=  11;
const int KEY_3		=  12;
const int KEY_4		=  13;
const int KEY_5		=  14;
const int KEY_6		=  15;
const int KEY_7		=  16;
const int KEY_8		=  17;
const int KEY_9		=  18;
const int KEY_0		=  19;

// characters
const int KEY_A		=  38;
const int KEY_B		=  56;
const int KEY_C		=  54;
const int KEY_D		=  40;
const int KEY_E		=  26;
const int KEY_F		=  41;
const int KEY_G		=  42;
const int KEY_H		=  43;
const int KEY_I		=  31;
const int KEY_J		=  44;
const int KEY_K		=  45;
const int KEY_L		=  46;
const int KEY_M		=  58;
const int KEY_N		=  57;
const int KEY_O		=  32;
const int KEY_P		=  33;
const int KEY_Q		=  24;
const int KEY_R		=  27;
const int KEY_S		=  39;
const int KEY_T		=  28;
const int KEY_U		=  30;
const int KEY_V		=  55;
const int KEY_W		=  25;
const int KEY_X		=  53;
const int KEY_Y		=  52;
const int KEY_Z		=  29;

// special
const int KEY_ESC	=   9;
const int KEY_TAB	=  23;
const int KEY_RETURN	=  36;
const int KEY_HOME	= 110;
const int KEY_UP	= 111;
const int KEY_PGUP	= 112;
const int KEY_LEFT	= 113;
const int KEY_RIGHT	= 114;
const int KEY_END	= 115;
const int KEY_DOWN	= 116;
const int KEY_PGDOWN	= 117;
const int KEY_INS	= 118;
const int KEY_DEL	= 118;

const int KEY_F1	=  67;
const int KEY_F2	=  68;
const int KEY_F3	=  69;
const int KEY_F4	=  70;
const int KEY_F5	=  71;
const int KEY_F6	=  72;
const int KEY_F7	=  73;
const int KEY_F8	=  74;
const int KEY_F9	=  75;
const int KEY_F10	=  76;
const int KEY_F11	=  95;
const int KEY_F12	=  96;
