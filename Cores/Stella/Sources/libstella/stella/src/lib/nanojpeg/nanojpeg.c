// NanoJPEG -- KeyJ's Tiny Baseline JPEG Decoder
// version 1.3.5 (2016-11-14)
// Copyright (c) 2009-2016 Martin J. Fiedler <martin.fiedler@gmx.net>
// published under the terms of the MIT license
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.


///////////////////////////////////////////////////////////////////////////////
// DOCUMENTATION SECTION                                                     //
// read this if you want to know what this is all about                      //
///////////////////////////////////////////////////////////////////////////////

// INTRODUCTION
// ============
//
// This is a minimal decoder for baseline JPEG images. It accepts memory dumps
// of JPEG files as input and generates either 8-bit grayscale or packed 24-bit
// RGB images as output. It does not parse JFIF or Exif headers; all JPEG files
// are assumed to be either grayscale or YCbCr. CMYK or other color spaces are
// not supported. All YCbCr subsampling schemes with power-of-two ratios are
// supported, as are restart intervals. Progressive or lossless JPEG is not
// supported.
// Summed up, NanoJPEG should be able to decode all images from digital cameras
// and most common forms of other non-progressive JPEG images.
// The decoder is not optimized for speed, it's optimized for simplicity and
// small code. Image quality should be at a reasonable level. A bicubic chroma
// upsampling filter ensures that subsampled YCbCr images are rendered in
// decent quality. The decoder is not meant to deal with broken JPEG files in
// a graceful manner; if anything is wrong with the bitstream, decoding will
// simply fail.
// The code should work with every modern C compiler without problems and
// should not emit any warnings. It uses only (at least) 32-bit integer
// arithmetic and is supposed to be endianness independent and 64-bit clean.
// However, it is not thread-safe.


// COMPILE-TIME CONFIGURATION
// ==========================
//
// The following aspects of NanoJPEG can be controlled with preprocessor
// defines:
//
// _NJ_EXAMPLE_PROGRAM     = Compile a main() function with an example
//                           program.
// _NJ_INCLUDE_HEADER_ONLY = Don't compile anything, just act as a header
//                           file for NanoJPEG. Example:
//                               #define _NJ_INCLUDE_HEADER_ONLY
//                               #include "nanojpeg.c"
//                               int main(void) {
//                                   njInit();
//                                   // your code here
//                                   njDone();
//                               }
// NJ_USE_LIBC=1           = Use the malloc(), free(), memset() and memcpy()
//                           functions from the standard C library (default).
// NJ_USE_LIBC=0           = Don't use the standard C library. In this mode,
//                           external functions njAlloc(), njFreeMem(),
//                           njFillMem() and njCopyMem() need to be defined
//                           and implemented somewhere.
// NJ_USE_WIN32=0          = Normal mode (default).
// NJ_USE_WIN32=1          = If compiling with MSVC for Win32 and
//                           NJ_USE_LIBC=0, NanoJPEG will use its own
//                           implementations of the required C library
//                           functions (default if compiling with MSVC and
//                           NJ_USE_LIBC=0).
// NJ_CHROMA_FILTER=1      = Use the bicubic chroma upsampling filter
//                           (default).
// NJ_CHROMA_FILTER=0      = Use simple pixel repetition for chroma upsampling
//                           (bad quality, but faster and less code).


// API
// ===
//
// For API documentation, read the "header section" below.


// EXAMPLE
// =======
//
// A few pages below, you can find an example program that uses NanoJPEG to
// convert JPEG files into PGM or PPM. To compile it, use something like
//     gcc -O3 -D_NJ_EXAMPLE_PROGRAM -o nanojpeg nanojpeg.c
// You may also add -std=c99 -Wall -Wextra -pedantic -Werror, if you want :)
// The only thing you might need is -Wno-shift-negative-value, because this
// code relies on the target machine using two's complement arithmetic, but
// the C standard does not, even though *any* practically useful machine
// nowadays uses two's complement.


///////////////////////////////////////////////////////////////////////////////
// HEADER SECTION                                                            //
// copy and pase this into nanojpeg.h if you want                            //
///////////////////////////////////////////////////////////////////////////////

#ifndef _NANOJPEG_H
#define _NANOJPEG_H

// nj_result_t: Result codes for njDecode().
typedef enum _nj_result {
    NJ_OK = 0,        // no error, decoding successful
    NJ_NO_JPEG,       // not a JPEG file
    NJ_UNSUPPORTED,   // unsupported format
    NJ_OUT_OF_MEM,    // out of memory
    NJ_INTERNAL_ERR,  // internal error
    NJ_SYNTAX_ERROR,  // syntax error
    __NJ_FINISHED,    // used internally, will never be reported
} nj_result_t;

// njInit: Initialize NanoJPEG.
// For safety reasons, this should be called at least one time before using
// using any of the other NanoJPEG functions.
void njInit(void);

// njDecode: Decode a JPEG image.
// Decodes a memory dump of a JPEG file into internal buffers.
// Parameters:
//   jpeg = The pointer to the memory dump.
//   size = The size of the JPEG file.
// Return value: The error code in case of failure, or NJ_OK (zero) on success.
nj_result_t njDecode(const void* jpeg, const int size);

// njGetWidth: Return the width (in pixels) of the most recently decoded
// image. If njDecode() failed, the result of njGetWidth() is undefined.
int njGetWidth(void);

// njGetHeight: Return the height (in pixels) of the most recently decoded
// image. If njDecode() failed, the result of njGetHeight() is undefined.
int njGetHeight(void);

// njIsColor: Return 1 if the most recently decoded image is a color image
// (RGB) or 0 if it is a grayscale image. If njDecode() failed, the result
// of njGetWidth() is undefined.
int njIsColor(void);

// njGetImage: Returns the decoded image data.
// Returns a pointer to the most recently image. The memory layout it byte-
// oriented, top-down, without any padding between lines. Pixels of color
// images will be stored as three consecutive bytes for the red, green and
// blue channels. This data format is thus compatible with the PGM or PPM
// file formats and the OpenGL texture formats GL_LUMINANCE8 or GL_RGB8.
// If njDecode() failed, the result of njGetImage() is undefined.
unsigned char* njGetImage(void);

// njGetImageSize: Returns the size (in bytes) of the image data returned
// by njGetImage(). If njDecode() failed, the result of njGetImageSize() is
// undefined.
int njGetImageSize(void);

// njDone: Uninitialize NanoJPEG.
// Resets NanoJPEG's internal state and frees all memory that has been
// allocated at run-time by NanoJPEG. It is still possible to decode another
// image after a njDone() call.
void njDone(void);

#endif//_NANOJPEG_H


///////////////////////////////////////////////////////////////////////////////
// CONFIGURATION SECTION                                                     //
// adjust the default settings for the NJ_ defines here                      //
///////////////////////////////////////////////////////////////////////////////

#ifndef NJ_USE_LIBC
    #define NJ_USE_LIBC 1
#endif

#ifndef NJ_USE_WIN32
  #ifdef _MSC_VER
    #define NJ_USE_WIN32 (!NJ_USE_LIBC)
  #else
    #define NJ_USE_WIN32 0
  #endif
#endif

#ifndef NJ_CHROMA_FILTER
    #define NJ_CHROMA_FILTER 1
#endif


///////////////////////////////////////////////////////////////////////////////
// EXAMPLE PROGRAM                                                           //
// just define _NJ_EXAMPLE_PROGRAM to compile this (requires NJ_USE_LIBC)    //
///////////////////////////////////////////////////////////////////////////////

#ifdef  _NJ_EXAMPLE_PROGRAM

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char* argv[]) {
    int size;
    char *buf;
    FILE *f;

    if (argc < 2) {
        printf("Usage: %s <input.jpg> [<output.ppm>]\n", argv[0]);
        return 2;
    }
    f = fopen(argv[1], "rb");
    if (!f) {
        printf("Error opening the input file.\n");
        return 1;
    }
    fseek(f, 0, SEEK_END);
    size = (int) ftell(f);
    buf = (char*) malloc(size);
    fseek(f, 0, SEEK_SET);
    size = (int) fread(buf, 1, size, f);
    fclose(f);

    njInit();
    if (njDecode(buf, size)) {
        free((void*)buf);
        printf("Error decoding the input file.\n");
        return 1;
    }
    free((void*)buf);

    f = fopen((argc > 2) ? argv[2] : (njIsColor() ? "nanojpeg_out.ppm" : "nanojpeg_out.pgm"), "wb");
    if (!f) {
        printf("Error opening the output file.\n");
        return 1;
    }
    fprintf(f, "P%d\n%d %d\n255\n", njIsColor() ? 6 : 5, njGetWidth(), njGetHeight());
    fwrite(njGetImage(), 1, njGetImageSize(), f);
    fclose(f);
    njDone();
    return 0;
}

#endif


///////////////////////////////////////////////////////////////////////////////
// IMPLEMENTATION SECTION                                                    //
// you may stop reading here                                                 //
///////////////////////////////////////////////////////////////////////////////

#ifndef _NJ_INCLUDE_HEADER_ONLY

#ifdef _MSC_VER
    #define NJ_INLINE static __inline
    #define NJ_FORCE_INLINE static __forceinline
#else
    #define NJ_INLINE static inline
    #define NJ_FORCE_INLINE static inline
#endif

#if NJ_USE_LIBC
    #include <stdlib.h>
    #include <string.h>
    #define njAllocMem malloc
    #define njFreeMem  free
    #define njFillMem  memset
    #define njCopyMem  memcpy
#elif NJ_USE_WIN32
    #include <windows.h>
    #define njAllocMem(size) ((void*) LocalAlloc(LMEM_FIXED, (SIZE_T)(size)))
    #define njFreeMem(block) ((void) LocalFree((HLOCAL) block))
    NJ_INLINE void njFillMem(void* block, unsigned char value, int count) { __asm {
        mov edi, block
        mov al, value
        mov ecx, count
        rep stosb
    } }
    NJ_INLINE void njCopyMem(void* dest, const void* src, int count) { __asm {
        mov edi, dest
        mov esi, src
        mov ecx, count
        rep movsb
    } }
#else
    extern void* njAllocMem(int size);
    extern void njFreeMem(void* block);
    extern void njFillMem(void* block, unsigned char byte, int size);
    extern void njCopyMem(void* dest, const void* src, int size);
#endif

typedef struct _nj_code {
    unsigned char bits, code;
} nj_vlc_code_t;

typedef struct _nj_cmp {
    int cid;
    int ssx, ssy;
    int width, height;
    int stride;
    int qtsel;
    int actabsel, dctabsel;
    int dcpred;
    unsigned char *pixels;
} nj_component_t;

typedef struct _nj_ctx {
    nj_result_t error;
    const unsigned char *pos;
    int size;
    int length;
    int width, height;
    int mbwidth, mbheight;
    int mbsizex, mbsizey;
    int ncomp;
    nj_component_t comp[3];
    int qtused, qtavail;
    unsigned char qtab[4][64];
    nj_vlc_code_t vlctab[4][65536];
    int buf, bufbits;
    int block[64];
    int rstinterval;
    unsigned char *rgb;
} nj_context_t;

static nj_context_t nj;

static const char njZZ[64] = { 0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18,
11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35,
42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45,
38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

NJ_FORCE_INLINE unsigned char njClip(const int x) {
    return (x < 0) ? 0 : ((x > 0xFF) ? 0xFF : (unsigned char) x);
}

#define W1 2841
#define W2 2676
#define W3 2408
#define W5 1609
#define W6 1108
#define W7 565

NJ_INLINE void njRowIDCT(int* blk) {
    int x0, x1, x2, x3, x4, x5, x6, x7, x8;
    if (!((x1 = blk[4] << 11)
        | (x2 = blk[6])
        | (x3 = blk[2])
        | (x4 = blk[1])
        | (x5 = blk[7])
        | (x6 = blk[5])
        | (x7 = blk[3])))
    {
        blk[0] = blk[1] = blk[2] = blk[3] = blk[4] = blk[5] = blk[6] = blk[7] = blk[0] << 3;
        return;
    }
    x0 = (blk[0] << 11) + 128;
    x8 = W7 * (x4 + x5);
    x4 = x8 + (W1 - W7) * x4;
    x5 = x8 - (W1 + W7) * x5;
    x8 = W3 * (x6 + x7);
    x6 = x8 - (W3 - W5) * x6;
    x7 = x8 - (W3 + W5) * x7;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2);
    x2 = x1 - (W2 + W6) * x2;
    x3 = x1 + (W2 - W6) * x3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    blk[0] = (x7 + x1) >> 8;
    blk[1] = (x3 + x2) >> 8;
    blk[2] = (x0 + x4) >> 8;
    blk[3] = (x8 + x6) >> 8;
    blk[4] = (x8 - x6) >> 8;
    blk[5] = (x0 - x4) >> 8;
    blk[6] = (x3 - x2) >> 8;
    blk[7] = (x7 - x1) >> 8;
}

NJ_INLINE void njColIDCT(const int* blk, unsigned char *out, int stride) {
    int x0, x1, x2, x3, x4, x5, x6, x7, x8;
    if (!((x1 = blk[8*4] << 8)
        | (x2 = blk[8*6])
        | (x3 = blk[8*2])
        | (x4 = blk[8*1])
        | (x5 = blk[8*7])
        | (x6 = blk[8*5])
        | (x7 = blk[8*3])))
    {
        x1 = njClip(((blk[0] + 32) >> 6) + 128);
        for (x0 = 8;  x0;  --x0) {
            *out = (unsigned char) x1;
            out += stride;
        }
        return;
    }
    x0 = (blk[0] << 8) + 8192;
    x8 = W7 * (x4 + x5) + 4;
    x4 = (x8 + (W1 - W7) * x4) >> 3;
    x5 = (x8 - (W1 + W7) * x5) >> 3;
    x8 = W3 * (x6 + x7) + 4;
    x6 = (x8 - (W3 - W5) * x6) >> 3;
    x7 = (x8 - (W3 + W5) * x7) >> 3;
    x8 = x0 + x1;
    x0 -= x1;
    x1 = W6 * (x3 + x2) + 4;
    x2 = (x1 - (W2 + W6) * x2) >> 3;
    x3 = (x1 + (W2 - W6) * x3) >> 3;
    x1 = x4 + x6;
    x4 -= x6;
    x6 = x5 + x7;
    x5 -= x7;
    x7 = x8 + x3;
    x8 -= x3;
    x3 = x0 + x2;
    x0 -= x2;
    x2 = (181 * (x4 + x5) + 128) >> 8;
    x4 = (181 * (x4 - x5) + 128) >> 8;
    *out = njClip(((x7 + x1) >> 14) + 128);  out += stride;
    *out = njClip(((x3 + x2) >> 14) + 128);  out += stride;
    *out = njClip(((x0 + x4) >> 14) + 128);  out += stride;
    *out = njClip(((x8 + x6) >> 14) + 128);  out += stride;
    *out = njClip(((x8 - x6) >> 14) + 128);  out += stride;
    *out = njClip(((x0 - x4) >> 14) + 128);  out += stride;
    *out = njClip(((x3 - x2) >> 14) + 128);  out += stride;
    *out = njClip(((x7 - x1) >> 14) + 128);
}

#define njThrow(e) do { nj.error = e; return; } while (0)
#define njCheckError() do { if (nj.error) return; } while (0)

static int njShowBits(int bits) {
    unsigned char newbyte;
    if (!bits) return 0;
    while (nj.bufbits < bits) {
        if (nj.size <= 0) {
            nj.buf = (nj.buf << 8) | 0xFF;
            nj.bufbits += 8;
            continue;
        }
        newbyte = *nj.pos++;
        nj.size--;
        nj.bufbits += 8;
        nj.buf = (nj.buf << 8) | newbyte;
        if (newbyte == 0xFF) {
            if (nj.size) {
                unsigned char marker = *nj.pos++;
                nj.size--;
                switch (marker) {
                    case 0x00:
                    case 0xFF:
                        break;
                    case 0xD9: nj.size = 0; break;
                    default:
                        if ((marker & 0xF8) != 0xD0)
                            nj.error = NJ_SYNTAX_ERROR;
                        else {
                            nj.buf = (nj.buf << 8) | marker;
                            nj.bufbits += 8;
                        }
                }
            } else
                nj.error = NJ_SYNTAX_ERROR;
        }
    }
    return (nj.buf >> (nj.bufbits - bits)) & ((1 << bits) - 1);
}

NJ_INLINE void njSkipBits(int bits) {
    if (nj.bufbits < bits)
        (void) njShowBits(bits);
    nj.bufbits -= bits;
}

NJ_INLINE int njGetBits(int bits) {
    int res = njShowBits(bits);
    njSkipBits(bits);
    return res;
}

NJ_INLINE void njByteAlign(void) {
    nj.bufbits &= 0xF8;
}

static void njSkip(int count) {
    nj.pos += count;
    nj.size -= count;
    nj.length -= count;
    if (nj.size < 0) nj.error = NJ_SYNTAX_ERROR;
}

NJ_INLINE unsigned short njDecode16(const unsigned char *pos) {
    return (pos[0] << 8) | pos[1];
}

static void njDecodeLength(void) {
    if (nj.size < 2) njThrow(NJ_SYNTAX_ERROR);
    nj.length = njDecode16(nj.pos);
    if (nj.length > nj.size) njThrow(NJ_SYNTAX_ERROR);
    njSkip(2);
}

NJ_INLINE void njSkipMarker(void) {
    njDecodeLength();
    njSkip(nj.length);
}

NJ_INLINE void njDecodeSOF(void) {
    int i, ssxmax = 0, ssymax = 0;
    nj_component_t* c;
    njDecodeLength();
    njCheckError();
    if (nj.length < 9) njThrow(NJ_SYNTAX_ERROR);
    if (nj.pos[0] != 8) njThrow(NJ_UNSUPPORTED);
    nj.height = njDecode16(nj.pos+1);
    nj.width = njDecode16(nj.pos+3);
    if (!nj.width || !nj.height) njThrow(NJ_SYNTAX_ERROR);
    nj.ncomp = nj.pos[5];
    njSkip(6);
    switch (nj.ncomp) {
        case 1:
        case 3:
            break;
        default:
            njThrow(NJ_UNSUPPORTED);
    }
    if (nj.length < (nj.ncomp * 3)) njThrow(NJ_SYNTAX_ERROR);
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        c->cid = nj.pos[0];
        if (!(c->ssx = nj.pos[1] >> 4)) njThrow(NJ_SYNTAX_ERROR);
        if (c->ssx & (c->ssx - 1)) njThrow(NJ_UNSUPPORTED);  // non-power of two
        if (!(c->ssy = nj.pos[1] & 15)) njThrow(NJ_SYNTAX_ERROR);
        if (c->ssy & (c->ssy - 1)) njThrow(NJ_UNSUPPORTED);  // non-power of two
        if ((c->qtsel = nj.pos[2]) & 0xFC) njThrow(NJ_SYNTAX_ERROR);
        njSkip(3);
        nj.qtused |= 1 << c->qtsel;
        if (c->ssx > ssxmax) ssxmax = c->ssx;
        if (c->ssy > ssymax) ssymax = c->ssy;
    }
    if (nj.ncomp == 1) {
        c = nj.comp;
        c->ssx = c->ssy = ssxmax = ssymax = 1;
    }
    nj.mbsizex = ssxmax << 3;
    nj.mbsizey = ssymax << 3;
    nj.mbwidth = (nj.width + nj.mbsizex - 1) / nj.mbsizex;
    nj.mbheight = (nj.height + nj.mbsizey - 1) / nj.mbsizey;
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        c->width = (nj.width * c->ssx + ssxmax - 1) / ssxmax;
        c->height = (nj.height * c->ssy + ssymax - 1) / ssymax;
        c->stride = nj.mbwidth * c->ssx << 3;
        if (((c->width < 3) && (c->ssx != ssxmax)) || ((c->height < 3) && (c->ssy != ssymax))) njThrow(NJ_UNSUPPORTED);
        if (!(c->pixels = (unsigned char*) njAllocMem(c->stride * nj.mbheight * c->ssy << 3))) njThrow(NJ_OUT_OF_MEM);
    }
    if (nj.ncomp == 3) {
        nj.rgb = (unsigned char*) njAllocMem(nj.width * nj.height * nj.ncomp);
        if (!nj.rgb) njThrow(NJ_OUT_OF_MEM);
    }
    njSkip(nj.length);
}

NJ_INLINE void njDecodeDHT(void) {
    int codelen, currcnt, remain, spread, i, j;
    nj_vlc_code_t *vlc;
    static unsigned char counts[16];
    njDecodeLength();
    njCheckError();
    while (nj.length >= 17) {
        i = nj.pos[0];
        if (i & 0xEC) njThrow(NJ_SYNTAX_ERROR);
        if (i & 0x02) njThrow(NJ_UNSUPPORTED);
        i = (i | (i >> 3)) & 3;  // combined DC/AC + tableid value
        for (codelen = 1;  codelen <= 16;  ++codelen)
            counts[codelen - 1] = nj.pos[codelen];
        njSkip(17);
        vlc = &nj.vlctab[i][0];
        remain = spread = 65536;
        for (codelen = 1;  codelen <= 16;  ++codelen) {
            spread >>= 1;
            currcnt = counts[codelen - 1];
            if (!currcnt) continue;
            if (nj.length < currcnt) njThrow(NJ_SYNTAX_ERROR);
            remain -= currcnt << (16 - codelen);
            if (remain < 0) njThrow(NJ_SYNTAX_ERROR);
            for (i = 0;  i < currcnt;  ++i) {
                register unsigned char code = nj.pos[i];
                for (j = spread;  j;  --j) {
                    vlc->bits = (unsigned char) codelen;
                    vlc->code = code;
                    ++vlc;
                }
            }
            njSkip(currcnt);
        }
        while (remain--) {
            vlc->bits = 0;
            ++vlc;
        }
    }
    if (nj.length) njThrow(NJ_SYNTAX_ERROR);
}

NJ_INLINE void njDecodeDQT(void) {
    int i;
    unsigned char *t;
    njDecodeLength();
    njCheckError();
    while (nj.length >= 65) {
        i = nj.pos[0];
        if (i & 0xFC) njThrow(NJ_SYNTAX_ERROR);
        nj.qtavail |= 1 << i;
        t = &nj.qtab[i][0];
        for (i = 0;  i < 64;  ++i)
            t[i] = nj.pos[i + 1];
        njSkip(65);
    }
    if (nj.length) njThrow(NJ_SYNTAX_ERROR);
}

NJ_INLINE void njDecodeDRI(void) {
    njDecodeLength();
    njCheckError();
    if (nj.length < 2) njThrow(NJ_SYNTAX_ERROR);
    nj.rstinterval = njDecode16(nj.pos);
    njSkip(nj.length);
}

static int njGetVLC(nj_vlc_code_t* vlc, unsigned char* code) {
    int value = njShowBits(16);
    int bits = vlc[value].bits;
    if (!bits) { nj.error = NJ_SYNTAX_ERROR; return 0; }
    njSkipBits(bits);
    value = vlc[value].code;
    if (code) *code = (unsigned char) value;
    bits = value & 15;
    if (!bits) return 0;
    value = njGetBits(bits);
    if (value < (1 << (bits - 1)))
        value += ((-1) << bits) + 1;
    return value;
}

NJ_INLINE void njDecodeBlock(nj_component_t* c, unsigned char* out) {
    unsigned char code = 0;
    int value, coef = 0;
    njFillMem(nj.block, 0, sizeof(nj.block));
    c->dcpred += njGetVLC(&nj.vlctab[c->dctabsel][0], NULL);
    nj.block[0] = (c->dcpred) * nj.qtab[c->qtsel][0];
    do {
        value = njGetVLC(&nj.vlctab[c->actabsel][0], &code);
        if (!code) break;  // EOB
        if (!(code & 0x0F) && (code != 0xF0)) njThrow(NJ_SYNTAX_ERROR);
        coef += (code >> 4) + 1;
        if (coef > 63) njThrow(NJ_SYNTAX_ERROR);
        nj.block[(int) njZZ[coef]] = value * nj.qtab[c->qtsel][coef];
    } while (coef < 63);
    for (coef = 0;  coef < 64;  coef += 8)
        njRowIDCT(&nj.block[coef]);
    for (coef = 0;  coef < 8;  ++coef)
        njColIDCT(&nj.block[coef], &out[coef], c->stride);
}

NJ_INLINE void njDecodeScan(void) {
    int i, mbx, mby, sbx, sby;
    int rstcount = nj.rstinterval, nextrst = 0;
    nj_component_t* c;
    njDecodeLength();
    njCheckError();
    if (nj.length < (4 + 2 * nj.ncomp)) njThrow(NJ_SYNTAX_ERROR);
    if (nj.pos[0] != nj.ncomp) njThrow(NJ_UNSUPPORTED);
    njSkip(1);
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        if (nj.pos[0] != c->cid) njThrow(NJ_SYNTAX_ERROR);
        if (nj.pos[1] & 0xEE) njThrow(NJ_SYNTAX_ERROR);
        c->dctabsel = nj.pos[1] >> 4;
        c->actabsel = (nj.pos[1] & 1) | 2;
        njSkip(2);
    }
    if (nj.pos[0] || (nj.pos[1] != 63) || nj.pos[2]) njThrow(NJ_UNSUPPORTED);
    njSkip(nj.length);
    for (mbx = mby = 0;;) {
        for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c)
            for (sby = 0;  sby < c->ssy;  ++sby)
                for (sbx = 0;  sbx < c->ssx;  ++sbx) {
                    njDecodeBlock(c, &c->pixels[((mby * c->ssy + sby) * c->stride + mbx * c->ssx + sbx) << 3]);
                    njCheckError();
                }
        if (++mbx >= nj.mbwidth) {
            mbx = 0;
            if (++mby >= nj.mbheight) break;
        }
        if (nj.rstinterval && !(--rstcount)) {
            njByteAlign();
            i = njGetBits(16);
            if (((i & 0xFFF8) != 0xFFD0) || ((i & 7) != nextrst)) njThrow(NJ_SYNTAX_ERROR);
            nextrst = (nextrst + 1) & 7;
            rstcount = nj.rstinterval;
            for (i = 0;  i < 3;  ++i)
                nj.comp[i].dcpred = 0;
        }
    }
    nj.error = __NJ_FINISHED;
}

#if NJ_CHROMA_FILTER

#define CF4A (-9)
#define CF4B (111)
#define CF4C (29)
#define CF4D (-3)
#define CF3A (28)
#define CF3B (109)
#define CF3C (-9)
#define CF3X (104)
#define CF3Y (27)
#define CF3Z (-3)
#define CF2A (139)
#define CF2B (-11)
#define CF(x) njClip(((x) + 64) >> 7)

NJ_INLINE void njUpsampleH(nj_component_t* c) {
    const int xmax = c->width - 3;
    unsigned char *out, *lin, *lout;
    int x, y;
    out = (unsigned char*) njAllocMem((c->width * c->height) << 1);
    if (!out) njThrow(NJ_OUT_OF_MEM);
    lin = c->pixels;
    lout = out;
    for (y = c->height;  y;  --y) {
        lout[0] = CF(CF2A * lin[0] + CF2B * lin[1]);
        lout[1] = CF(CF3X * lin[0] + CF3Y * lin[1] + CF3Z * lin[2]);
        lout[2] = CF(CF3A * lin[0] + CF3B * lin[1] + CF3C * lin[2]);
        for (x = 0;  x < xmax;  ++x) {
            lout[(x << 1) + 3] = CF(CF4A * lin[x] + CF4B * lin[x + 1] + CF4C * lin[x + 2] + CF4D * lin[x + 3]);
            lout[(x << 1) + 4] = CF(CF4D * lin[x] + CF4C * lin[x + 1] + CF4B * lin[x + 2] + CF4A * lin[x + 3]);
        }
        lin += c->stride;
        lout += c->width << 1;
        lout[-3] = CF(CF3A * lin[-1] + CF3B * lin[-2] + CF3C * lin[-3]);
        lout[-2] = CF(CF3X * lin[-1] + CF3Y * lin[-2] + CF3Z * lin[-3]);
        lout[-1] = CF(CF2A * lin[-1] + CF2B * lin[-2]);
    }
    c->width <<= 1;
    c->stride = c->width;
    njFreeMem((void*)c->pixels);
    c->pixels = out;
}

NJ_INLINE void njUpsampleV(nj_component_t* c) {
    const int w = c->width, s1 = c->stride, s2 = s1 + s1;
    unsigned char *out, *cin, *cout;
    int x, y;
    out = (unsigned char*) njAllocMem((c->width * c->height) << 1);
    if (!out) njThrow(NJ_OUT_OF_MEM);
    for (x = 0;  x < w;  ++x) {
        cin = &c->pixels[x];
        cout = &out[x];
        *cout = CF(CF2A * cin[0] + CF2B * cin[s1]);  cout += w;
        *cout = CF(CF3X * cin[0] + CF3Y * cin[s1] + CF3Z * cin[s2]);  cout += w;
        *cout = CF(CF3A * cin[0] + CF3B * cin[s1] + CF3C * cin[s2]);  cout += w;
        cin += s1;
        for (y = c->height - 3;  y;  --y) {
            *cout = CF(CF4A * cin[-s1] + CF4B * cin[0] + CF4C * cin[s1] + CF4D * cin[s2]);  cout += w;
            *cout = CF(CF4D * cin[-s1] + CF4C * cin[0] + CF4B * cin[s1] + CF4A * cin[s2]);  cout += w;
            cin += s1;
        }
        cin += s1;
        *cout = CF(CF3A * cin[0] + CF3B * cin[-s1] + CF3C * cin[-s2]);  cout += w;
        *cout = CF(CF3X * cin[0] + CF3Y * cin[-s1] + CF3Z * cin[-s2]);  cout += w;
        *cout = CF(CF2A * cin[0] + CF2B * cin[-s1]);
    }
    c->height <<= 1;
    c->stride = c->width;
    njFreeMem((void*) c->pixels);
    c->pixels = out;
}

#else

NJ_INLINE void njUpsample(nj_component_t* c) {
    int x, y, xshift = 0, yshift = 0;
    unsigned char *out, *lin, *lout;
    while (c->width < nj.width) { c->width <<= 1; ++xshift; }
    while (c->height < nj.height) { c->height <<= 1; ++yshift; }
    out = (unsigned char*) njAllocMem(c->width * c->height);
    if (!out) njThrow(NJ_OUT_OF_MEM);
    lin = c->pixels;
    lout = out;
    for (y = 0;  y < c->height;  ++y) {
        lin = &c->pixels[(y >> yshift) * c->stride];
        for (x = 0;  x < c->width;  ++x)
            lout[x] = lin[x >> xshift];
        lout += c->width;
    }
    c->stride = c->width;
    njFreeMem((void*) c->pixels);
    c->pixels = out;
}

#endif

NJ_INLINE void njConvert(void) {
    int i;
    nj_component_t* c;
    for (i = 0, c = nj.comp;  i < nj.ncomp;  ++i, ++c) {
        #if NJ_CHROMA_FILTER
            while ((c->width < nj.width) || (c->height < nj.height)) {
                if (c->width < nj.width) njUpsampleH(c);
                njCheckError();
                if (c->height < nj.height) njUpsampleV(c);
                njCheckError();
            }
        #else
            if ((c->width < nj.width) || (c->height < nj.height))
                njUpsample(c);
        #endif
        if ((c->width < nj.width) || (c->height < nj.height)) njThrow(NJ_INTERNAL_ERR);
    }
    if (nj.ncomp == 3) {
        // convert to RGB
        int x, yy;
        unsigned char *prgb = nj.rgb;
        const unsigned char *py  = nj.comp[0].pixels;
        const unsigned char *pcb = nj.comp[1].pixels;
        const unsigned char *pcr = nj.comp[2].pixels;
        for (yy = nj.height;  yy;  --yy) {
            for (x = 0;  x < nj.width;  ++x) {
                register int y = py[x] << 8;
                register int cb = pcb[x] - 128;
                register int cr = pcr[x] - 128;
                *prgb++ = njClip((y            + 359 * cr + 128) >> 8);
                *prgb++ = njClip((y -  88 * cb - 183 * cr + 128) >> 8);
                *prgb++ = njClip((y + 454 * cb            + 128) >> 8);
            }
            py += nj.comp[0].stride;
            pcb += nj.comp[1].stride;
            pcr += nj.comp[2].stride;
        }
    } else if (nj.comp[0].width != nj.comp[0].stride) {
        // grayscale -> only remove stride
        unsigned char *pin = &nj.comp[0].pixels[nj.comp[0].stride];
        unsigned char *pout = &nj.comp[0].pixels[nj.comp[0].width];
        int y;
        for (y = nj.comp[0].height - 1;  y;  --y) {
            njCopyMem(pout, pin, nj.comp[0].width);
            pin += nj.comp[0].stride;
            pout += nj.comp[0].width;
        }
        nj.comp[0].stride = nj.comp[0].width;
    }
}

void njInit(void) {
    njFillMem(&nj, 0, sizeof(nj_context_t));
}

void njDone(void) {
    int i;
    for (i = 0;  i < 3;  ++i)
        if (nj.comp[i].pixels) njFreeMem((void*) nj.comp[i].pixels);
    if (nj.rgb) njFreeMem((void*) nj.rgb);
    njInit();
}

nj_result_t njDecode(const void* jpeg, const int size) {
    njDone();
    nj.pos = (const unsigned char*) jpeg;
    nj.size = size & 0x7FFFFFFF;
    if (nj.size < 2) return NJ_NO_JPEG;
    if ((nj.pos[0] ^ 0xFF) | (nj.pos[1] ^ 0xD8)) return NJ_NO_JPEG;
    njSkip(2);
    while (!nj.error) {
        if ((nj.size < 2) || (nj.pos[0] != 0xFF)) return NJ_SYNTAX_ERROR;
        njSkip(2);
        switch (nj.pos[-1]) {
            case 0xC0: njDecodeSOF();  break;
            case 0xC4: njDecodeDHT();  break;
            case 0xDB: njDecodeDQT();  break;
            case 0xDD: njDecodeDRI();  break;
            case 0xDA: njDecodeScan(); break;
            case 0xFE: njSkipMarker(); break;
            default:
                if ((nj.pos[-1] & 0xF0) == 0xE0)
                    njSkipMarker();
                else
                    return NJ_UNSUPPORTED;
        }
    }
    if (nj.error != __NJ_FINISHED) return nj.error;
    nj.error = NJ_OK;
    njConvert();
    return nj.error;
}

int njGetWidth(void)            { return nj.width; }
int njGetHeight(void)           { return nj.height; }
int njIsColor(void)             { return (nj.ncomp != 1); }
unsigned char* njGetImage(void) { return (nj.ncomp == 1) ? nj.comp[0].pixels : nj.rgb; }
int njGetImageSize(void)        { return nj.width * nj.height * nj.ncomp; }

#endif // _NJ_INCLUDE_HEADER_ONLY
