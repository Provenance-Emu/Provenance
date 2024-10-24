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

#ifndef __TXFILTER_H__
#define __TXFILTER_H__

#include "TxInternal.h"
#include "TxQuantize.h"
#include "TxHiResCache.h"
#include "TxTexCache.h"
#include "TxUtil.h"
#include "TxImage.h"

class TxFilter
{
private:
  int _numcore;

  uint8 *_tex1;
  uint8 *_tex2;
  int _maxwidth;
  int _maxheight;
  int _maxbpp;
  int _options;
  int _cacheSize;
  tx_wstring _ident;
  tx_wstring _dumpPath;
  TxQuantize *_txQuantize;
  TxTexCache *_txTexCache;
  TxHiResCache *_txHiResCache;
  TxImage *_txImage;
  boolean _initialized;
  void clear();
public:
  ~TxFilter();
  TxFilter(int maxwidth,
		   int maxheight,
		   int maxbpp,
		   int options,
		   int cachesize,
		   const wchar_t * texCachePath,
		   const wchar_t * texDumpPath,
		   const wchar_t * texPackPath,
		   const wchar_t * ident,
		   dispInfoFuncExt callback);
  boolean filter(uint8 *src,
				  int srcwidth,
				  int srcheight,
				  ColorFormat srcformat,
				  uint64 g64crc, /* glide64 crc, 64bit for future use */
				  GHQTexInfo *info);
  boolean hirestex(uint64 g64crc, /* glide64 crc, 64bit for future use */
				   uint64 r_crc64,   /* checksum hi:palette low:texture */
				   uint16 *palette,
				   GHQTexInfo *info);
  uint64 checksum64(uint8 *src, int width, int height, int size, int rowStride, uint8 *palette);
  boolean dmptx(uint8 *src, int width, int height, int rowStridePixel, ColorFormat gfmt, uint16 n64fmt, uint64 r_crc64);
  boolean reloadhirestex();
  void dumpcache();
};

#endif /* __TXFILTER_H__ */
