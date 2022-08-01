/*
 * Convert BDF files to C++ source.
 *
 * Copyright (c) 2002 by Greg Haerr <greg@censoft.com>
 *
 * Originally writen for the Microwindows Project <http://microwindows.org>
 *
 * Greg then modified it for Rockbox <http://rockbox.haxx.se/>
 *
 * Max Horn took that version and changed it to work for ScummVM.
 * Changes include: warning fixes, removed .FNT output, output C++ source,
 * tweak code generator so that the generated code fits into ScummVM code base.
 *
 * What fun it is converting font data...
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int READ_UINT16(void *addr) {
  unsigned char *buf = addr;
  return (buf[0] << 8) | buf[1];
}

void WRITE_UINT16(void *addr, int value) {
  unsigned char *buf = addr;
  buf[0] = (value >> 8) & 0xFF;
  buf[1] = value & 0xFF;
}

/* BEGIN font.h*/
/* uInt16 helper macros*/
#define BITMAP_WORDS(x)     (((x)+15)/16) /* image size in words*/
#define BITMAP_BYTES(x)     (BITMAP_WORDS(x)*sizeof(uInt16))
#define BITMAP_BITSPERIMAGE (sizeof(uInt16) * 8)
#define BITMAP_BITVALUE(n)  ((uInt16) (((uInt16) 1) << (n)))
#define BITMAP_FIRSTBIT     (BITMAP_BITVALUE(BITMAP_BITSPERIMAGE - 1))
#define BITMAP_TESTBIT(m)   ((m) & BITMAP_FIRSTBIT)
#define BITMAP_SHIFTBIT(m)  ((uInt16) ((m) << 1))

typedef unsigned short uInt16; /* bitmap image unit size*/

typedef struct {
  signed char w;
  signed char h;
  signed char x;
  signed char y;
} BBX;

/* builtin C-based proportional/fixed font structure */
/* based on The Microwindows Project http://microwindows.org */
struct font {
  char *  name;   /* font name*/
  int   maxwidth; /* max width in pixels*/
  int   height;   /* height in pixels*/
  int fbbw, fbbh, fbbx, fbby; /* max bounding box */
  int   ascent;   /* ascent (baseline) height*/
  int   firstchar;  /* first character in bitmap*/
  int   size;   /* font size in glyphs*/
  uInt16* bits;   /* 16-bit right-padded bitmap data*/
  unsigned long* offset;  /* offsets into bitmap data*/
  unsigned char* width; /* character widths or NULL if fixed*/
  BBX*  bbx;    /* character bounding box or NULL if fixed*/
  int   defaultchar;  /* default char (not glyph index)*/
  long  bits_size;  /* # words of uInt16 bits*/

  /* unused by runtime system, read in by convbdf*/
  char *  facename; /* facename of font*/
  char *  copyright;  /* copyright info for loadable fonts*/
  int   pixel_size;
  int   descent;
};
/* END font.h*/

#define isprefix(buf,str) (!strncmp(buf, str, strlen(str)))
#define strequal(s1,s2)   (!strcmp(s1, s2))

#define EXTRA 300   /* # bytes extra allocation for buggy .bdf files*/

int gen_map = 1;
int start_char = 0;
int limit_char = 65535;
int oflag = 0;
char outfile[256];
char fontname[256];
char fontnameU[256];

void usage(void);
void getopts(int *pac, char ***pav);
int convbdf(char *path);

void free_font(struct font* pf);
struct font* bdf_read_font(char *path);
int bdf_read_header(FILE *fp, struct font* pf);
int bdf_read_bitmaps(FILE *fp, struct font* pf);
char * bdf_getline(FILE *fp, char *buf, int len);
uInt16 bdf_hexval(unsigned char *buf);

int gen_c_source(struct font* pf, char *path);

void error(const char *s, ...) {
  char buf[1024];
  va_list va;

  va_start(va, s);
  vsnprintf(buf, 1024, s, va);
  va_end(va);

  fprintf(stderr, "ERROR: %s!\n", buf);

  exit(1);
}

void warning(const char *s, ...) {
  char buf[1024];
  va_list va;

  va_start(va, s);
  vsnprintf(buf, 1024, s, va);
  va_end(va);

  fprintf(stderr, "WARNING: %s!\n", buf);
}

void
usage(void)
{
  char help[] = {
  "Usage: convbdf [options] [input-files]\n"
  "   convbdf [options] [-o output-file] [single-input-file]\n"
  "Options:\n"
  "  -s N Start output at character encodings >= N\n"
  "  -l N Limit output to character encodings <= N\n"
  "  -f N Name to use for the font in the C++ code\n"
  "  -n     Don't generate bitmaps as comments in .c file\n"
  };

  fprintf(stderr, "%s", help);
}

/* parse command line options*/
void getopts(int *pac, char ***pav)
{
  const char *p;
  char **av;
  int ac;

  outfile[0] = '\0';
  fontname[0] = '\0';
  fontnameU[0] = '\0';

  ac = *pac;
  av = *pav;
  while (ac > 0 && av[0][0] == '-') {
    p = &av[0][1];
    while (*p) {
      switch (*p++) {
      case ' ':     /* multiple -args on av[]*/
        while (*p && *p == ' ')
          p++;
        if (*p++ != '-')  /* next option must have dash*/
          p = "";
        break;      /* proceed to next option*/
      case 'n':     /* don't gen bitmap comments*/
        gen_map = 0;
        break;
      case 'o':     /* set output file*/
        oflag = 1;
        if (*p) {
          strcpy(outfile, p);
          while (*p && *p != ' ')
            p++;
        }
        else {
          av++; ac--;
          if (ac > 0)
            strcpy(outfile, av[0]);
        }
        break;
      case 'l':     /* set encoding limit*/
        if (*p) {
          limit_char = atoi(p);
          while (*p && *p != ' ')
            p++;
        }
        else {
          av++; ac--;
          if (ac > 0)
            limit_char = atoi(av[0]);
        }
        break;
      case 's':     /* set encoding start*/
        if (*p) {
          start_char = atoi(p);
          while (*p && *p != ' ')
            p++;
        }
        else {
          av++; ac--;
          if (ac > 0)
            start_char = atoi(av[0]);
        }
        break;
      case 'f':     /* set font name*/
        if (*p) {
          strcpy(fontname, p);
          while (*p && *p != ' ')
            p++;
        }
        else {
          av++; ac--;
          if (ac > 0)
            strcpy(fontname, av[0]);
        }
        {
          char* u;
          strcpy(fontnameU, fontname);
          u = fontnameU;
          while(*u=toupper(*u))
            *u++;
        }
        break;
      default:
        fprintf(stderr, "Unknown option ignored: %c\r\n", *(p-1));
      }
    }
    ++av; --ac;
  }
  *pac = ac;
  *pav = av;
}

/* remove directory prefix and file suffix from full path*/
char *basename(char *path)
{
  char *p, *b;
  static char base[256];

  /* remove prepended path and extension*/
  b = path;
  for (p = path; *p; ++p) {
    if (*p == '/')
      b = p + 1;
  }
  strcpy(base, b);
  for (p = base; *p; ++p) {
    if (*p == '.') {
      *p = 0;
      break;
    }
  }
  return base;
}

int convbdf(char *path)
{
  struct font* pf;
  int ret = 0;

  pf = bdf_read_font(path);
  if (!pf)
    exit(1);

  if (!oflag) {
    strcpy(outfile, basename(path));
    strcat(outfile, ".hxx");
  }
  ret |= gen_c_source(pf, outfile);

  free_font(pf);
  return ret;
}

int main(int ac, char *av[])
{
  int ret = 0;

  ++av; --ac;   /* skip av[0]*/
  getopts(&ac, &av);  /* read command line options*/

  if (ac < 1) {
    usage();
    exit(1);
  }
  if (oflag && ac > 1) {
    usage();
    exit(1);
  }

  while (ac > 0) {
    ret |= convbdf(av[0]);
    ++av; --ac;
  }

  exit(ret);
}

/* free font structure*/
void free_font(struct font* pf)
{
  if (!pf)
    return;
  free(pf->name);
  free(pf->facename);
  free(pf->bits);
  free(pf->offset);
  free(pf->width);
  free(pf);
}

/* build incore structure from .bdf file*/
struct font* bdf_read_font(char *path)
{
  FILE *fp;
  struct font* pf;

  fp = fopen(path, "rb");
  if (!fp) {
    fprintf(stderr, "Error opening file: %s\n", path);
    return NULL;
  }

  pf = (struct font*)calloc(1, sizeof(struct font));
  if (!pf)
    goto errout;

  pf->name = strdup(basename(path));

  if (!bdf_read_header(fp, pf)) {
    fprintf(stderr, "Error reading font header\n");
    goto errout;
  }

  if (!bdf_read_bitmaps(fp, pf)) {
    fprintf(stderr, "Error reading font bitmaps\n");
    goto errout;
  }

  fclose(fp);
  return pf;

 errout:
  fclose(fp);
  free_font(pf);
  return NULL;
}

/* read bdf font header information, return 0 on error*/
int bdf_read_header(FILE *fp, struct font* pf)
{
  int encoding;
  int nchars, maxwidth;
  int firstchar = 65535;
  int lastchar = -1;
  char buf[256];
  char facename[256];
  char copyright[256];

  /* set certain values to errors for later error checking*/
  pf->defaultchar = -1;
  pf->ascent = -1;
  pf->descent = -1;

  for (;;) {
    if (!bdf_getline(fp, buf, sizeof(buf))) {
      fprintf(stderr, "Error: EOF on file\n");
      return 0;
    }
    if (isprefix(buf, "FONT ")) {   /* not required*/
      if (sscanf(buf, "FONT %[^\n]", facename) != 1) {
        fprintf(stderr, "Error: bad 'FONT'\n");
        return 0;
      }
      pf->facename = strdup(facename);
      continue;
    }
    if (isprefix(buf, "COPYRIGHT ")) {  /* not required*/
      if (sscanf(buf, "COPYRIGHT \"%[^\"]", copyright) != 1) {
        fprintf(stderr, "Error: bad 'COPYRIGHT'\n");
        return 0;
      }
      pf->copyright = strdup(copyright);
      continue;
    }
    if (isprefix(buf, "DEFAULT_CHAR ")) { /* not required*/
      if (sscanf(buf, "DEFAULT_CHAR %d", &pf->defaultchar) != 1) {
        fprintf(stderr, "Error: bad 'DEFAULT_CHAR'\n");
        return 0;
      }
    }
    if (isprefix(buf, "FONT_DESCENT ")) {
      if (sscanf(buf, "FONT_DESCENT %d", &pf->descent) != 1) {
        fprintf(stderr, "Error: bad 'FONT_DESCENT'\n");
        return 0;
      }
      continue;
    }
    if (isprefix(buf, "FONT_ASCENT ")) {
      if (sscanf(buf, "FONT_ASCENT %d", &pf->ascent) != 1) {
        fprintf(stderr, "Error: bad 'FONT_ASCENT'\n");
        return 0;
      }
      continue;
    }
    if (isprefix(buf, "FONTBOUNDINGBOX ")) {
      if (sscanf(buf, "FONTBOUNDINGBOX %d %d %d %d",
             &pf->fbbw, &pf->fbbh, &pf->fbbx, &pf->fbby) != 4) {
        fprintf(stderr, "Error: bad 'FONTBOUNDINGBOX'\n");
        return 0;
      }
      continue;
    }
    if (isprefix(buf, "CHARS ")) {
      if (sscanf(buf, "CHARS %d", &nchars) != 1) {
        fprintf(stderr, "Error: bad 'CHARS'\n");
        return 0;
      }
      continue;
    }

    /*
     * Reading ENCODING is necessary to get firstchar/lastchar
     * which is needed to pre-calculate our offset and widths
     * array sizes.
     */
    if (isprefix(buf, "ENCODING ")) {
      if (sscanf(buf, "ENCODING %d", &encoding) != 1) {
        fprintf(stderr, "Error: bad 'ENCODING'\n");
        return 0;
      }
      if (encoding >= 0 &&
        encoding <= limit_char &&
        encoding >= start_char) {

        if (firstchar > encoding)
          firstchar = encoding;
        if (lastchar < encoding)
          lastchar = encoding;
      }
      continue;
    }
    if (strequal(buf, "ENDFONT"))
      break;
  }

  /* calc font height*/
  if (pf->ascent < 0 || pf->descent < 0 || firstchar < 0) {
    fprintf(stderr, "Error: Invalid BDF file, requires FONT_ASCENT/FONT_DESCENT/ENCODING\n");
    return 0;
  }
  pf->height = pf->ascent + pf->descent;

  /* calc default char*/
  if (pf->defaultchar < 0 ||
    pf->defaultchar < firstchar ||
    pf->defaultchar > limit_char )
    pf->defaultchar = firstchar;

  /* calc font size (offset/width entries)*/
  pf->firstchar = firstchar;
  pf->size = lastchar - firstchar + 1;

  /* use the font boundingbox to get initial maxwidth*/
  /*maxwidth = pf->fbbw - pf->fbbx;*/
  maxwidth = pf->fbbw;

  /* initially use font maxwidth * height for bits allocation*/
  pf->bits_size = nchars * BITMAP_WORDS(maxwidth) * pf->height;

  /* allocate bits, offset, and width arrays*/
  pf->bits = (uInt16 *)malloc(pf->bits_size * sizeof(uInt16) + EXTRA);
  pf->offset = (unsigned long *)malloc(pf->size * sizeof(unsigned long));
  pf->width = (unsigned char *)malloc(pf->size * sizeof(unsigned char));
  pf->bbx = (BBX *)malloc(pf->size * sizeof(BBX));

  if (!pf->bits || !pf->offset || !pf->width) {
    fprintf(stderr, "Error: no memory for font load\n");
    return 0;
  }

  return 1;
}

/* read bdf font bitmaps, return 0 on error*/
int bdf_read_bitmaps(FILE *fp, struct font* pf)
{
  long ofs = 0;
  int maxwidth = 0;
  int i, k, encoding, width;
  int bbw, bbh, bbx, bby;
  int proportional = 0;
  int need_bbx = 0;
  int encodetable = 0;
  long l;
  char buf[256];

  /* reset file pointer*/
  fseek(fp, 0L, SEEK_SET);

  /* initially mark offsets as not used*/
  for (i = 0; i < pf->size; ++i)
    pf->offset[i] = -1;

  for (;;) {
    if (!bdf_getline(fp, buf, sizeof(buf))) {
      fprintf(stderr, "Error: EOF on file\n");
      return 0;
    }
    if (isprefix(buf, "STARTCHAR")) {
      encoding = width = bbw = bbh = bbx = bby = -1;
      continue;
    }
    if (isprefix(buf, "ENCODING ")) {
      if (sscanf(buf, "ENCODING %d", &encoding) != 1) {
        fprintf(stderr, "Error: bad 'ENCODING'\n");
        return 0;
      }
      if (encoding < start_char || encoding > limit_char)
        encoding = -1;
      continue;
    }
    if (isprefix(buf, "DWIDTH ")) {
      if (sscanf(buf, "DWIDTH %d", &width) != 1) {
        fprintf(stderr, "Error: bad 'DWIDTH'\n");
        return 0;
      }
      /* use font boundingbox width if DWIDTH <= 0*/
      if (width <= 0)
        width = pf->fbbw - pf->fbbx;
      continue;
    }
    if (isprefix(buf, "BBX ")) {
      if (sscanf(buf, "BBX %d %d %d %d", &bbw, &bbh, &bbx, &bby) != 4) {
        fprintf(stderr, "Error: bad 'BBX'\n");
        return 0;
      }
      continue;
    }
    if (strequal(buf, "BITMAP")) {
      uInt16 *ch_bitmap = pf->bits + ofs;
      int ch_words;

      if (encoding < 0)
        continue;

      /* set bits offset in encode map*/
      if (pf->offset[encoding-pf->firstchar] != (unsigned long)-1) {
        fprintf(stderr, "Error: duplicate encoding for character %d (0x%02x), ignoring duplicate\n",
            encoding, encoding);
        continue;
      }
      pf->offset[encoding-pf->firstchar] = ofs;
      pf->width[encoding-pf->firstchar] = width;

      pf->bbx[encoding-pf->firstchar].w = bbw;
      pf->bbx[encoding-pf->firstchar].h = bbh;
      pf->bbx[encoding-pf->firstchar].x = bbx;
      pf->bbx[encoding-pf->firstchar].y = bby;

      if (width > maxwidth)
        maxwidth = width;

      /* clear bitmap*/
      memset(ch_bitmap, 0, BITMAP_BYTES(bbw) * bbh);

      ch_words = BITMAP_WORDS(bbw);

      /* read bitmaps*/
      for (i = 0; i < bbh; ++i) {
        if (!bdf_getline(fp, buf, sizeof(buf))) {
          fprintf(stderr, "Error: EOF reading BITMAP data\n");
          return 0;
        }
        if (isprefix(buf, "ENDCHAR"))
          break;

        for (k = 0; k < ch_words; ++k) {
          uInt16 value;

          value = bdf_hexval((unsigned char *)buf);

          if (bbw > 8) {
            WRITE_UINT16(ch_bitmap, value);
          } else {
            WRITE_UINT16(ch_bitmap, value << 8);
          }
          ch_bitmap++;
        }
      }

      // If the default glyph is completely empty, the next
      // glyph will not be dumped. Work around this by
      // never generating completely empty glyphs.

      if (bbh == 0 && bbw == 0) {
        pf->bbx[encoding-pf->firstchar].w = 1;
        pf->bbx[encoding-pf->firstchar].h = 1;
        *ch_bitmap++ = 0;
        ofs++;
      } else {
        ofs += ch_words * bbh;
      }
      continue;
    }
    if (strequal(buf, "ENDFONT"))
      break;
  }

  /* set max width*/
  pf->maxwidth = maxwidth;

  /* change unused offset/width values to default char values*/
  for (i = 0; i < pf->size; ++i) {
    int defchar = pf->defaultchar - pf->firstchar;

    if (pf->offset[i] == (unsigned long)-1) {
      pf->offset[i] = pf->offset[defchar];
      pf->width[i] = pf->width[defchar];
      pf->bbx[i].w = pf->bbx[defchar].w;
      pf->bbx[i].h = pf->bbx[defchar].h;
      pf->bbx[i].x = pf->bbx[defchar].x;
      pf->bbx[i].y = pf->bbx[defchar].y;
    }
  }

  /* determine whether font doesn't require encode table*/
  l = 0;
  for (i = 0; i < pf->size; ++i) {
    if (pf->offset[i] != l) {
      encodetable = 1;
      break;
    }
    l += BITMAP_WORDS(pf->bbx[i].w) * pf->bbx[i].h;
  }
  if (!encodetable) {
    free(pf->offset);
    pf->offset = NULL;
  }

  /* determine whether font is fixed-width*/
  for (i = 0; i < pf->size; ++i) {
    if (pf->width[i] != maxwidth) {
      proportional = 1;
      break;
    }
  }
  if (!proportional) {
    free(pf->width);
    pf->width = NULL;
  }

  /* determine if the font needs a bbx table */
  for (i = 0; i < pf->size; ++i) {
    if (pf->bbx[i].w != pf->fbbw || pf->bbx[i].h != pf->fbbh || pf->bbx[i].x != pf->fbbx || pf->bbx[i].y != pf->fbby) {
      need_bbx = 1;
      break;
    }
  }
  if (!need_bbx) {
    free(pf->bbx);
    pf->bbx = NULL;
  }

  /* reallocate bits array to actual bits used*/
  if (ofs < pf->bits_size) {
    pf->bits = realloc(pf->bits, ofs * sizeof(uInt16));
    pf->bits_size = ofs;
  }
  else {
    if (ofs > pf->bits_size) {
      fprintf(stderr, "Warning: DWIDTH spec > max FONTBOUNDINGBOX\n");
      if (ofs > pf->bits_size+EXTRA) {
        fprintf(stderr, "Error: Not enough bits initially allocated\n");
        return 0;
      }
      pf->bits_size = ofs;
    }
  }

  return 1;
}

/* read the next non-comment line, returns buf or NULL if EOF*/
char *bdf_getline(FILE *fp, char *buf, int len)
{
  int c;
  char *b;

  for (;;) {
    b = buf;
    while ((c = getc(fp)) != EOF) {
      if (c == '\r')
        continue;
      if (c == '\n')
        break;
      if (b - buf >= (len - 1))
        break;
      *b++ = c;
    }
    *b = '\0';
    if (c == EOF && b == buf)
      return NULL;
    if (b != buf && !isprefix(buf, "COMMENT"))
      break;
  }
  return buf;
}

/* return hex value of buffer */
uInt16 bdf_hexval(unsigned char *buf) {
  uInt16 val = 0;
  unsigned char *ptr;

  for (ptr = buf; *ptr; ptr++) {
    int c = *ptr;

    if (c >= '0' && c <= '9')
      c -= '0';
    else if (c >= 'A' && c <= 'F')
      c = c - 'A' + 10;
    else if (c >= 'a' && c <= 'f')
      c = c - 'a' + 10;
    else
      c = 0;
    val = (val << 4) | c;
  }
  return val;
}

/* generate C source from in-core font*/
int gen_c_source(struct font* pf, char *path)
{
  FILE *ofp;
  int h, i;
  int did_defaultchar = 0;
  int did_syncmsg = 0;
  time_t t = time(0);
  uInt16 *ofs = pf->bits;
  char buf[256];
  char obuf[256];
  char bbuf[256];
  char hdr1[] = {
    "//============================================================================\n"
    "//\n"
    "//   SSSS    tt          lll  lll\n"
    "//  SS  SS   tt           ll   ll\n"
    "//  SS     tttttt  eeee   ll   ll   aaaa\n"
    "//   SSSS    tt   ee  ee  ll   ll      aa\n"
    "//      SS   tt   eeeeee  ll   ll   aaaaa  --  \"An Atari 2600 VCS Emulator\"\n"
    "//  SS  SS   tt   ee      ll   ll  aa  aa\n"
    "//   SSSS     ttt  eeeee llll llll  aaaaa\n"
    "//\n"
    "// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony\n"
    "// and the Stella Team\n"
    "//\n"
    "// See the file \"License.txt\" for information on usage and redistribution of\n"
    "// this file, and for a DISCLAIMER OF ALL WARRANTIES.\n"
    "//\n"
    "// Generated by src/tools/convbdf on %s.\n"
    "//============================================================================\n"
    "\n"
    "#ifndef %s_FONT_DATA_HXX\n"
    "#define %s_FONT_DATA_HXX\n"
    "\n"
    "#include \"Font.hxx\"\n"
    "\n"
    "/* Font information:\n"
    "   name: %s\n"
    "   facename: %s\n"
    "   w x h: %dx%d\n"
    "   bbx: %d %d %d %d\n"
    "   size: %d\n"
    "   ascent: %d\n"
    "   descent: %d\n"
    "   first char: %d (0x%02x)\n"
    "   last char: %d (0x%02x)\n"
    "   default char: %d (0x%02x)\n"
    "   proportional: %s\n"
    "   %s\n"
    "*/\n"
    "\n"
    "namespace GUI {\n"
    "\n"
    "// Font character bitmap data.\n"
    "static const uInt16 %s_font_bits[] = {  // NOLINT : too complicated to convert\n"
  };

  ofp = fopen(path, "w");
  if (!ofp) {
    fprintf(stderr, "Can't create %s\n", path);
    return 1;
  }

  strcpy(buf, ctime(&t));
  buf[strlen(buf) - 1] = 0;

  fprintf(ofp, hdr1, buf,
      fontnameU, fontnameU,
      pf->name,
      pf->facename? pf->facename: "",
      pf->maxwidth, pf->height,
      pf->fbbw, pf->fbbh, pf->fbbx, pf->fbby,
      pf->size,
      pf->ascent, pf->descent,
      pf->firstchar, pf->firstchar,
      pf->firstchar+pf->size-1, pf->firstchar+pf->size-1,
      pf->defaultchar, pf->defaultchar,
      pf->width? "yes": "no",
      pf->copyright? pf->copyright: "",
      fontname);

  /* generate bitmaps*/
  for (i = 0; i < pf->size; ++i) {
    int x;
    int bitcount = 0;
    int width = pf->bbx ? pf->bbx[i].w : pf->fbbw;
    int height = pf->bbx ? pf->bbx[i].h : pf->fbbh;
    int xoff = pf->bbx ? pf->bbx[i].x : pf->fbbx;
    int yoff = pf->bbx ? pf->bbx[i].y : pf->fbby;
    uInt16 *bits = pf->bits + (pf->offset? pf->offset[i]: (height * i));
    uInt16 bitvalue = 0;

    /*
     * Generate bitmap bits only if not this index isn't
     * the default character in encode map, or the default
     * character hasn't been generated yet.
     */
    if (pf->offset &&
      (pf->offset[i] == pf->offset[pf->defaultchar-pf->firstchar])) {
      if (did_defaultchar)
        continue;
      did_defaultchar = 1;
    }

    fprintf(ofp, "\n/* Character %d (0x%02x):\n   width %d\n   bbx ( %d, %d, %d, %d )\n",
        i+pf->firstchar, i+pf->firstchar,
        pf->width ? pf->width[i+pf->firstchar] : pf->maxwidth,
        width, height, xoff, yoff);

    if (gen_map) {
      fprintf(ofp, "\n   +");
      for (x=0; x<width; ++x) fprintf(ofp, "-");
      fprintf(ofp, "+\n");

      x = 0;
      h = height;
      while (h > 0) {
        if (x == 0) fprintf(ofp, "   |");

        if (bitcount <= 0) {
          bitcount = BITMAP_BITSPERIMAGE;
          bitvalue = READ_UINT16(bits);
          bits++;
        }

        fprintf(ofp, BITMAP_TESTBIT(bitvalue)? "*": " ");

        bitvalue = BITMAP_SHIFTBIT(bitvalue);
        --bitcount;
        if (++x == width) {
          fprintf(ofp, "|\n");
          --h;
          x = 0;
          bitcount = 0;
        }
      }
      fprintf(ofp, "   +");
      for (x = 0; x < width; ++x)
        fprintf(ofp, "-");
      fprintf(ofp, "+\n*/\n");
    } else
      fprintf(ofp, "\n*/\n");

    bits = pf->bits + (pf->offset? pf->offset[i]: (height * i));
    for (x = BITMAP_WORDS(width) * height; x > 0; --x) {
      fprintf(ofp, "0x%04x,\n", READ_UINT16(bits));
      if (!did_syncmsg && *bits++ != *ofs++) {
        fprintf(stderr, "Warning: found encoding values in non-sorted order (not an error).\n");
        did_syncmsg = 1;
      }
    }
  }
  fprintf(ofp, "};\n\n");

  if (pf->offset) {
    /* output offset table*/
    fprintf(ofp, "/* Character->glyph mapping. */\n"
        "static const uInt32 %s_sysfont_offset[] = {\n", fontname);

    for (i = 0; i < pf->size; ++i)
      fprintf(ofp, "  %ld,\t/* (0x%02x) */\n",
          pf->offset[i], i+pf->firstchar);
    fprintf(ofp, "};\n\n");
  }

  /* output width table for proportional fonts*/
  if (pf->width) {
    fprintf(ofp, "/* Character width data. */\n"
        "static const unsigned char %s_sysfont_width[] = {\n", fontname);

    for (i = 0; i < pf->size; ++i)
      fprintf(ofp, "  %d,\t/* (0x%02x) */\n",
          pf->width[i], i+pf->firstchar);
    fprintf(ofp, "};\n\n");
  }

  /* output bbox table */
  if (pf->bbx) {
    fprintf(ofp, "/* Bounding box data. */\n"
        "static const BBX %s_sysfont_bbx[] = {\n", fontname);

    for (i = 0; i < pf->size; ++i)
      fprintf(ofp, "\t{ %d, %d, %d, %d },\t/* (0x%02x) */\n",
        pf->bbx[i].w, pf->bbx[i].h, pf->bbx[i].x, pf->bbx[i].y, i+pf->firstchar);
    fprintf(ofp, "};\n\n");
  }

  /* output struct font struct*/
  if (pf->offset)
    sprintf(obuf, "%s_sysfont_offset,", fontname);
  else
    sprintf(obuf, "nullptr,  /* no encode table*/");

  if (pf->width)
    sprintf(buf, "%s_sysfont_width,", fontname);
  else
    sprintf(buf, "nullptr,  /* fixed width*/");

  if (pf->bbx)
    sprintf(bbuf, "%s_sysfont_bbx,", fontname);
  else
    sprintf(bbuf, "nullptr,  /* fixed bbox*/");

  fprintf(ofp,
      "/* Exported structure definition. */\n"
      "static const FontDesc %sDesc = {\n"
      "  \"%s\",\n"
      "  %d,\n"
      "  %d,\n"
      "  %d, %d, %d, %d,\n"
      "  %d,\n"
      "  %d,\n"
      "  %d,\n"
      "  %s_font_bits,\n"
      "  %s\n"
      "  %s\n"
      "  %s\n"
      "  %d,\n"
      "  sizeof(%s_font_bits)/sizeof(uInt16)\n"
      "};\n",
      fontname,
      pf->name,
      pf->maxwidth, pf->height,
      pf->fbbw, pf->fbbh, pf->fbbx, pf->fbby,
      pf->ascent,
      pf->firstchar,
      pf->size,
      fontname,
      obuf,
      buf,
      bbuf,
      pf->defaultchar,
      fontname);

  fprintf(ofp, "\n} // End of namespace GUI\n\n#endif\n");
  fclose(ofp);

  return 0;
}
