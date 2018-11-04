
void bgr444_to_rgb32(void *to, void *from);
void bgr444_to_rgb32_sh(void *to, void *from);

void vidcpy_m2(void *dest, void *src, int m32col, int with_32c_border);
void vidcpy_m2_rot(void *dest, void *src, int m32col, int with_32c_border);
void spend_cycles(int c); // utility

void rotated_blit8 (void *dst, void *linesx4, int y, int is_32col);
void rotated_blit16(void *dst, void *linesx4, int y, int is_32col);
