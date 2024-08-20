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

#include <memory.h>
#include <stdlib.h>
#include "Ext_TxFilter.h"

typedef boolean (*txfilter_init)(int maxwidth, int maxheight, int maxbpp,
								 int options, int cachesize,
								 const wchar_t *path, const wchar_t *ident,
								 dispInfoFuncExt callback);

typedef void (*txfilter_shutdown)(void);

typedef boolean (*txfilter_filter)(unsigned char *src, int srcwidth, int srcheight, unsigned short srcformat,
								   uint64 g64crc, GHQTexInfo *info);

typedef boolean (*txfilter_hirestex)(uint64 g64crc, uint64 r_crc64, unsigned short *palette, GHQTexInfo *info);

typedef uint64 (*txfilter_checksum)(unsigned char *src, int width, int height, int size, int rowStride, unsigned char *palette);

typedef boolean (*txfilter_dmptx)(unsigned char *src, int width, int height, int rowStridePixel, unsigned short gfmt, unsigned short n64fmt, uint64 r_crc64);

typedef boolean (*txfilter_reloadhirestex)();

static struct {
  TXHMODULE lib;
  txfilter_init init;
  txfilter_shutdown shutdown;
  txfilter_filter filter;
  txfilter_hirestex hirestex;
  txfilter_checksum checksum;
  txfilter_dmptx dmptx;
  txfilter_reloadhirestex reloadhirestex;
} txfilter;

void ext_ghq_shutdown(void)
{
  if (txfilter.shutdown)
	(*txfilter.shutdown)();

  if (txfilter.lib) {
	DLCLOSE(txfilter.lib);
	memset(&txfilter, 0, sizeof(txfilter));
  }
}

boolean ext_ghq_init(int maxwidth, int maxheight, int maxbpp, int options, int cachesize,
					 const wchar_t *path, const wchar_t *ident,
					 dispInfoFuncExt callback)
{
  boolean bRet = 0;

  if (!txfilter.lib) {
	wchar_t curpath[MAX_PATH];
	wcscpy(curpath, path);
#ifdef WIN32
#ifdef GHQCHK
	wcscat(curpath, wst("\\ghqchk.dll"));
#else
	wcscat(curpath, wst("\\GlideHQ.dll"));
#endif
	txfilter.lib = DLOPEN(curpath);
#else
	char cbuf[MAX_PATH];
#ifdef GHQCHK
	wcscat(curpath, wst("/ghqchk.so"));
#else
	wcscat(curpath, wst("/GlideHQ.so"));
#endif
	wcstombs(cbuf, curpath, MAX_PATH);
	txfilter.lib = DLOPEN(cbuf);
#endif
  }

  if (txfilter.lib) {
	if (!txfilter.init)
	  txfilter.init = (txfilter_init)DLSYM(txfilter.lib, "txfilter_init");
	if (!txfilter.shutdown)
	  txfilter.shutdown = (txfilter_shutdown)DLSYM(txfilter.lib, "txfilter_shutdown");
	if (!txfilter.filter)
	  txfilter.filter = (txfilter_filter)DLSYM(txfilter.lib, "txfilter_filter");
	if (!txfilter.hirestex)
	  txfilter.hirestex = (txfilter_hirestex)DLSYM(txfilter.lib, "txfilter_hirestex");
	if (!txfilter.checksum)
	  txfilter.checksum = (txfilter_checksum)DLSYM(txfilter.lib, "txfilter_checksum");
	if (!txfilter.dmptx)
	  txfilter.dmptx = (txfilter_dmptx)DLSYM(txfilter.lib, "txfilter_dmptx");
	if (!txfilter.reloadhirestex)
	  txfilter.reloadhirestex = (txfilter_reloadhirestex)DLSYM(txfilter.lib, "txfilter_reloadhirestex");
  }

  if (txfilter.init && txfilter.shutdown && txfilter.filter &&
	  txfilter.hirestex && txfilter.checksum /*&& txfilter.dmptx && txfilter.reloadhirestex */)
	bRet = (*txfilter.init)(maxwidth, maxheight, maxbpp, options, cachesize, path, ident, callback);
  else
	ext_ghq_shutdown();

  return bRet;
}

boolean ext_ghq_txfilter(unsigned char *src, int srcwidth, int srcheight, unsigned short srcformat,
								uint64 g64crc, GHQTexInfo *info)
{
  boolean ret = 0;

  if (txfilter.filter)
	ret = (*txfilter.filter)(src, srcwidth, srcheight, srcformat,
							 g64crc, info);

  return ret;
}

boolean ext_ghq_hirestex(uint64 g64crc, uint64 r_crc64, unsigned short *palette, GHQTexInfo *info)
{
  boolean ret = 0;

  if (txfilter.hirestex)
	ret = (*txfilter.hirestex)(g64crc, r_crc64, palette, info);

  return ret;
}

uint64 ext_ghq_checksum(unsigned char *src, int width, int height, int size, int rowStride, unsigned char *palette)
{
  uint64 ret = 0;

  if (txfilter.checksum)
	ret = (*txfilter.checksum)(src, width, height, size, rowStride, palette);

  return ret;
}

boolean ext_ghq_dmptx(unsigned char *src, int width, int height, int rowStridePixel, unsigned short gfmt, unsigned short n64fmt, uint64 r_crc64)
{
  boolean ret = 0;

  if (txfilter.dmptx)
	ret = (*txfilter.dmptx)(src, width, height, rowStridePixel, gfmt, n64fmt, r_crc64);

  return ret;
}

boolean ext_ghq_reloadhirestex()
{
  boolean ret = 0;

  if (txfilter.reloadhirestex)
	ret = (*txfilter.reloadhirestex)();

  return ret;
}
