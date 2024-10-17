
extern unsigned char fontdata8x8[64*16];
extern unsigned char fontdata6x8[256-32][8];

void basic_text_out16_nf(void *fb, int w, int x, int y, const char *text);
void basic_text_out16(void *fb, int w, int x, int y, const char *texto, ...);
void basic_text_out_uyvy_nf(void *fb, int w, int x, int y, const char *text);
