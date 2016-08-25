/* Configure library by modifying this file */

#ifndef NES_NTSC_CONFIG_H
#define NES_NTSC_CONFIG_H

/* Uncomment to enable emphasis support and use a 512 color palette instead
of the base 64 color palette. */
/*#define NES_NTSC_EMPHASIS 1*/

/* The following affect the built-in blitter only; a custom blitter can
handle things however it wants. */

// CUSTOM: Made this use a variable, so it can be changed for output.
/* Bits per pixel of output. Can be 15, 16, 32, or 24 (same as 32). */
//#define NES_NTSC_OUT_DEPTH OutputDepth

/* Type of input pixel values. You'll probably use unsigned short
if you enable emphasis above. */
#define NES_NTSC_IN_T unsigned char

// CUSTOM: (XBuf uses bit 0x80, and has palettes above 0x3f for LUA)
/* Each raw pixel input value is passed through this. You might want to mask
the pixel index if you use the high bits as flags, etc. */
#define NES_NTSC_ADJ_IN( in ) ((in & 0x3f) | emphasis)

/* For each pixel, this is the basic operation:
output_color = color_palette [NES_NTSC_ADJ_IN( NES_NTSC_IN_T )] */

#endif
