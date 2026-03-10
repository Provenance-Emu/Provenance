
void bgr444_to_rgb32(void *to, void *from, unsigned entries);
void bgr444_to_rgb32_sh(void *to, void *from);

void vidcpy_8bit(void *dest, void *src, int x_y, int w_h);
void vidcpy_8bit_rot(void *dest, void *src, int x_y, int w_h);

void spend_cycles(int c); // utility

void rotated_blit8 (void *dst, void *linesx4, int y, int is_32col);
void rotated_blit16(void *dst, void *linesx4, int y, int is_32col);
