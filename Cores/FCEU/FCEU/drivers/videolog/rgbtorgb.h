#ifdef __cplusplus
extern "C" {
  #define defaulttrue =true
#else
  #define defaulttrue
  #define bool       int
#endif

/* RGB to RGB and RGB from/to YCbRr (YUV) conversions written by Bisqwit
 * Copyright (C) 1992,2008 Joel Yliluoma (http://iki.fi/bisqwit/)
 *
 * Concepts:
 *   15 = RGB15 or BGR15
 *   16 = RGB16 or BGR16
 *   24 = RGB24 or BGR24
 *   32 = RGB32 or BGR32
 * I420 = YCbCr where Y is issued for each pixel,
 *                    followed by Cr for 2x2 pixels,
 *                    followed by Cb for 2x2 pixels
 * YUY2 = YCbCr where for each pixel, Y is issued,
 *                    followed by Cr for 2x1 pixels (if even pixel)
 *                             or Cb for 2x1 pixels (if odd pixel)
 *
 * Note: Not all functions honor the swap_red_blue setting.
 */

void Convert32To24Frame(const void* data, unsigned char* dest, unsigned npixels)
    __attribute__((noinline));

void Convert15To24Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert16To24Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert15To32Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert16To32Frame(const void* data, unsigned char* dest, unsigned npixels, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert24To16Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);

void Convert24To15Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);

void Convert_I420To24Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert15To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert16To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert24To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert32To_I420Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);

void Convert_YUY2To24Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width, bool swap_red_blue defaulttrue)
    __attribute__((noinline));

void Convert15To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert16To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert24To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);
void Convert32To_YUY2Frame(const void* data, unsigned char* dest, unsigned npixels, unsigned width);

#ifdef __cplusplus
}
  #undef defaulttrue
#else
  #undef defaulttrue
  #undef bool
#endif
