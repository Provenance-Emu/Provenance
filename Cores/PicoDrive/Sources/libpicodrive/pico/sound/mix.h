
//void mix_32_to_32(int *dest, int *src, int count);
void mix_16h_to_32(s32 *dest, s16 *src, int count);
void mix_16h_to_32_s1(s32 *dest, s16 *src, int count);
void mix_16h_to_32_s2(s32 *dest, s16 *src, int count);

void mix_16h_to_32_resample_stereo(s32 *dest, s16 *src, int count, int fac16);
void mix_16h_to_32_resample_mono(s32 *dest, s16 *src, int count, int fac16);
void mix_32_to_16_stereo(s16 *dest, s32 *src, int count);
void mix_32_to_16_mono(s16 *dest, s32 *src, int count);

extern int mix_32_to_16_level;
void mix_32_to_16_stereo_lvl(s16 *dest, s32 *src, int count);
void mix_reset(int alpha_q16);
