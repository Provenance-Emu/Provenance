/*
 * Texture Filtering
 * Version:  1.0
 *
 * Copyright (C) 2007  Hiroshi Morii   All Rights Reserved.
 * Email koolsmoky(at)users.sourceforge.net
 * Web   http://www.3dfxzone.it/koolsmoky
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * this is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Make; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include "../Ext_TxFilter.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

void DisplayLoadProgress(const wchar_t *format, ...)
{
#if 0
  va_list args;
  wchar_t wbuf[INFO_BUF];
  char buf[INFO_BUF];

  /* process input */
  va_start(args, format);
  vswprintf(wbuf, format, args);
  va_end(args);

  /* XXX: convert to multibyte */
  wcstombs(buf, wbuf, INFO_BUF);
  printf(buf);
#else
  static unsigned int i = 0;
  i++;
  if (i == 1) printf("\b-");
  else if (i == 2) printf("\b\\");
  else if (i == 3) printf("\b|");
  else {
	printf("\b/");
	i = 0;
  }
#endif
}

int main(int argc, char* argv[])
{
  float dummy = 1.1; /* force the compiler to load floating point support */
  boolean bret = 0;
  int options = 0;

  /* Plugin path */
  wchar_t path[MAX_PATH];
#ifdef WIN32
  GETCWD(MAX_PATH, path);
#else
  char cbuf[MAX_PATH];
  GETCWD(MAX_PATH, cbuf);
  mbstowcs(path, cbuf, MAX_PATH);
#endif

  /* ROM name */
  wchar_t name[21] = L"DEFAULT";

  printf("------------------------------------------------------------------\n");
  printf("  GlideHQ Hires Texture Checker version 1.2\n");
  printf("  Copyright (C) 2010  Hiroshi Morii   All Rights Reserved\n");
  printf("     email   : koolsmoky(at)users.sourceforge.net\n");
  printf("     website : http://www.3dfxzone.it/koolsmoky\n");
  printf("\n");
  printf("  Glide64 official website : http://glide64.emuxhaven.net\n");
  printf("\n");
  printf("  Usage: ghqchk.exe \"INTERNAL ROM NAME\"\n");
  printf("------------------------------------------------------------------\n");

  if (argc != 2) return 0;

  printf("Checking \"%s\"...  ", argv[1]);

  mbstowcs(name, argv[1], 21);

  //options |= COMPRESS_TEX;
  //options |= COMPRESS_HIRESTEX;
  //options |= S3TC_COMPRESSION;
  //options |= TILE_HIRESTEX;
  //options |= FORCE16BPP_TEX;
  //options |= FORCE16BPP_HIRESTEX;
  //options |= GZ_TEXCACHE;
  options |= GZ_HIRESTEXCACHE;
  //options |= (DUMP_TEXCACHE|DUMP_HIRESTEXCACHE);
  options |= LET_TEXARTISTS_FLY;
  //options |= DUMP_TEX;
  options |= RICE_HIRESTEXTURES;

  bret = ext_ghq_init(1024, // max texture width supported by hardware
					  1024, // max texture height supported by hardware
					  32, // max texture bpp supported by hardware
					  options,
					  0, // cache texture to system memory
					  path, // plugin path
					  name, // name of ROM. must be no longer than 256 characters
					  DisplayLoadProgress);

  ext_ghq_shutdown();

  printf("\bDone!\nLogged to ghqchk.txt\n");

  return bret;
}
