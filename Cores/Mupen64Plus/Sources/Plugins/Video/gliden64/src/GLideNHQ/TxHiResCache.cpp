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

/* 2007 Gonetz <gonetz(at)ngs.ru>
 * Added callback to display hires texture info. */

#ifdef __MSC__
#pragma warning(disable: 4786)
#endif

/* use power of 2 texture size
 * (0:disable, 1:enable, 2:3dfx) */
#define POW2_TEXTURES 0

/* use aggressive format assumption for quantization
 * (0:disable, 1:enable, 2:extreme) */
#define AGGRESSIVE_QUANTIZATION 1

#include "TxHiResCache.h"
#include "TxDbg.h"
#include <osal_files.h>
#include <zlib.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

TxHiResCache::~TxHiResCache()
{
  delete _txImage;
  delete _txQuantize;
  delete _txReSample;
}

TxHiResCache::TxHiResCache(int maxwidth,
						   int maxheight,
						   int maxbpp,
						   int options,
						   const wchar_t *cachePath,
						   const wchar_t *texPackPath,
						   const wchar_t *ident,
						   dispInfoFuncExt callback)
	: TxCache((options & ~GZ_TEXCACHE), 0, cachePath, ident, callback)
{
  _txImage = new TxImage();
  _txQuantize  = new TxQuantize();
  _txReSample = new TxReSample();

  _maxwidth  = maxwidth;
  _maxheight = maxheight;
  _maxbpp    = maxbpp;
  _abortLoad = 0;
  _cacheDumped = 0;

  if (texPackPath)
	  _texPackPath.assign(texPackPath);

  if (_cachePath.empty() || _ident.empty()) {
	_options &= ~DUMP_HIRESTEXCACHE;
	return;
  }

  /* read in hires texture cache */
  if (_options & DUMP_HIRESTEXCACHE) {
	/* find it on disk */
	_cacheDumped = TxCache::load(_cachePath.c_str(), _getFileName().c_str(), _getConfig(), !_HiResTexPackPathExists());
  }

/* read in hires textures */
  if (!_cacheDumped) {
	  if (TxHiResCache::load(0) && (_options & DUMP_HIRESTEXCACHE) != 0)
		  _cacheDumped = TxCache::save(_cachePath.c_str(), _getFileName().c_str(), _getConfig());
  }
}

void TxHiResCache::dump()
{
	if ((_options & DUMP_HIRESTEXCACHE) && !_cacheDumped && !_abortLoad && !empty()) {
	  /* dump cache to disk */
	  _cacheDumped = TxCache::save(_cachePath.c_str(), _getFileName().c_str(), _getConfig());
	}
}

tx_wstring TxHiResCache::_getFileName() const
{
	tx_wstring filename = _ident + wst("_HIRESTEXTURES.") + TEXCACHE_EXT;
	removeColon(filename);
	return filename;
}

int TxHiResCache::_getConfig() const
{
	return _options & (HIRESTEXTURES_MASK | TILE_HIRESTEX | FORCE16BPP_HIRESTEX | GZ_HIRESTEXCACHE | LET_TEXARTISTS_FLY);
}

boolean TxHiResCache::_HiResTexPackPathExists() const
{
	tx_wstring dir_path(_texPackPath);
	dir_path += OSAL_DIR_SEPARATOR_STR;
	dir_path += _ident;
	return osal_path_existsW(dir_path.c_str());
}

boolean TxHiResCache::empty()
{
  return _cache.empty();
}

boolean TxHiResCache::load(boolean replace) /* 0 : reload, 1 : replace partial */
{
	if (_texPackPath.empty() || _ident.empty())
		return 0;

	if (!replace) TxCache::clear();

	tx_wstring dir_path(_texPackPath);

	switch (_options & HIRESTEXTURES_MASK) {
	case RICE_HIRESTEXTURES:
		INFO(80, wst("-----\n"));
		INFO(80, wst("using Rice hires texture format...\n"));
		INFO(80, wst("  must be one of the following;\n"));
		INFO(80, wst("    1) *_rgb.png + *_a.png\n"));
		INFO(80, wst("    2) *_all.png\n"));
		INFO(80, wst("    3) *_ciByRGBA.png\n"));
		INFO(80, wst("    4) *_allciByRGBA.png\n"));
		INFO(80, wst("    5) *_ci.bmp\n"));
		INFO(80, wst("  usage of only 2) and 3) highly recommended!\n"));
		INFO(80, wst("  folder names must be in US-ASCII characters!\n"));

		dir_path += OSAL_DIR_SEPARATOR_STR;
		dir_path += _ident;

		const LoadResult res = loadHiResTextures(dir_path.c_str(), replace);
		if (res == resError) {
			if (_callback) (*_callback)(wst("Texture pack load failed. Clear hiresolution texture cache.\n"));
			INFO(80, wst("Texture pack load failed. Clear hiresolution texture cache.\n"));
			_cache.clear();
		}
		return res == resOk ? 1 : 0;
	}
	return 0;
}

TxHiResCache::LoadResult
TxHiResCache::loadHiResTextures(const wchar_t * dir_path, boolean replace)
{
  DBG_INFO(80, wst("-----\n"));
  DBG_INFO(80, wst("path: %ls\n"), dir_path);

  /* find it on disk */
  if (!osal_path_existsW(dir_path)) {
	INFO(80, wst("Error: path not found!\n"));
	return resNotFound;
  }

  LoadResult result = resOk;

#ifdef OS_WINDOWS
  wchar_t curpath[MAX_PATH];
  GETCWD(MAX_PATH, curpath);
  CHDIR(dir_path);
#else
  char curpath[MAX_PATH];
  char cbuf[MAX_PATH];
  wcstombs(cbuf, dir_path, MAX_PATH);
  GETCWD(MAX_PATH, curpath);
  CHDIR(cbuf);
#endif

  void *dir = osal_search_dir_open(dir_path);
  const wchar_t *foundfilename;
  // the path of the texture
  tx_wstring texturefilename;

  do {

	if (KBHIT(0x1B)) {
	  _abortLoad = 1;
	  if (_callback) (*_callback)(wst("Aborted loading hiresolution texture!\n"));
	  INFO(80, wst("Error: aborted loading hiresolution texture!\n"));
	}
	if (_abortLoad) break;

	foundfilename = osal_search_dir_read_next(dir);
	// The array is empty,  break the current operation
	if (foundfilename == nullptr)
		break;
	// The current file is a hidden one
	if (wccmp(foundfilename, wst(".")))
		// These files we don't need
		continue;
	texturefilename.assign(dir_path);
	texturefilename += OSAL_DIR_SEPARATOR_STR;
	texturefilename += foundfilename;

	/* recursive read into sub-directory */
	if (osal_is_directory(texturefilename.c_str())) {
		result = loadHiResTextures(texturefilename.c_str(), replace);
		if (result == resOk)
			continue;
		else
			break;
	}

	DBG_INFO(80, wst("-----\n"));
	DBG_INFO(80, wst("file: %ls\n"), foundfilename);

	int width = 0, height = 0;
	ColorFormat format = graphics::internalcolorFormat::NOCOLOR;
	uint8 *tex = nullptr;
	int tmpwidth = 0, tmpheight = 0;
	ColorFormat tmpformat = graphics::internalcolorFormat::NOCOLOR;
	uint8 *tmptex= nullptr;
	ColorFormat destformat = graphics::internalcolorFormat::NOCOLOR;

	/* Rice hi-res textures: begin
	 */
	uint32 chksum = 0, fmt = 0, siz = 0, palchksum = 0;
	char *pfname = nullptr, fname[MAX_PATH];
	std::string ident;
	FILE *fp = nullptr;

	wcstombs(fname, _ident.c_str(), MAX_PATH);
	/* XXX case sensitivity fiasco!
	 * files must use _a, _rgb, _all, _allciByRGBA, _ciByRGBA, _ci
	 * and file extensions must be in lower case letters! */
#ifdef OS_WINDOWS
	{
	  unsigned int i;
	  for (i = 0; i < strlen(fname); i++) fname[i] = tolower(fname[i]);
	}
#endif
	ident.assign(fname);

	/* read in Rice's file naming convention */
#define CRCFMTSIZ_LEN 13
#define PALCRC_LEN 9
	wcstombs(fname, foundfilename, MAX_PATH);
	/* XXX case sensitivity fiasco!
	 * files must use _a, _rgb, _all, _allciByRGBA, _ciByRGBA, _ci
	 * and file extensions must be in lower case letters! */
#ifdef OS_WINDOWS
	{
	  unsigned int i;
	  for (i = 0; i < strlen(fname); i++) fname[i] = tolower(fname[i]);
	}
#endif
	pfname = fname + strlen(fname) - 4;
	if (!(pfname == strstr(fname, ".png") ||
		  pfname == strstr(fname, ".bmp") ||
		  pfname == strstr(fname, ".dds"))) {
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
	  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
	  INFO(80, wst("Error: not png or bmp or dds!\n"));
	  continue;
	}
	pfname = strstr(fname, ident.c_str());
	if (pfname != fname) pfname = 0;
	if (pfname) {
	  if (sscanf(pfname + ident.size(), "#%08X#%01X#%01X#%08X", &chksum, &fmt, &siz, &palchksum) == 4)
		pfname += (ident.size() + CRCFMTSIZ_LEN + PALCRC_LEN);
	  else if (sscanf(pfname + ident.size(), "#%08X#%01X#%01X", &chksum, &fmt, &siz) == 3)
		pfname += (ident.size() + CRCFMTSIZ_LEN);
	  else
		pfname = 0;
	}
	if (!pfname) {
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n", dir_path));
	  INFO(80, wst("file: %ls\n", foundfilename));
#endif
	  INFO(80, wst("Error: not Rice texture naming convention!\n"));
	  continue;
	}
	if (!chksum) {
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
	  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
	  INFO(80, wst("Error: crc32 = 0!\n"));
	  continue;
	}

	/* check if we already have it in hires texture cache */
	if (!replace) {
	  uint64 chksum64 = (uint64)palchksum;
	  chksum64 <<= 32;
	  chksum64 |= (uint64)chksum;
	  if (TxCache::is_cached(chksum64)) {
#if !DEBUG
		INFO(80, wst("-----\n"));
		INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
		INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
		INFO(80, wst("Error: already cached! duplicate texture!\n"));
		continue;
	  }
	}

	DBG_INFO(80, wst("rom: %ls chksum:%08X %08X fmt:%x size:%x\n"), _ident.c_str(), chksum, palchksum, fmt, siz);

	/* Deal with the wackiness some texture packs utilize Rice format.
	 * Read in the following order: _a.* + _rgb.*, _all.png _ciByRGBA.png,
	 * _allciByRGBA.png, and _ci.bmp. PNG are prefered over BMP.
	 *
	 * For some reason there are texture packs that include them all. Some
	 * even have RGB textures named as _all.* and ARGB textures named as
	 * _rgb.*... Someone pleeeez write a GOOD guideline for the texture
	 * designers!!!
	 *
	 * We allow hires textures to have higher bpp than the N64 originals.
	 */
	/* N64 formats
	 * Format: 0 - RGBA, 1 - YUV, 2 - CI, 3 - IA, 4 - I
	 * Size:   0 - 4bit, 1 - 8bit, 2 - 16bit, 3 - 32 bit
	 */

	/*
	 * read in _rgb.* and _a.*
	 */
	if (pfname == strstr(fname, "_rgb.") || pfname == strstr(fname, "_a.")) {
	  strcpy(pfname, "_rgb.png");
	  if (!osal_path_existsA(fname)) {
		strcpy(pfname, "_rgb.bmp");
		if (!osal_path_existsA(fname)) {
#if !DEBUG
		  INFO(80, wst("-----\n"));
		  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
		  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
		  INFO(80, wst("Error: missing _rgb.*! _a.* must be paired with _rgb.*!\n"));
		  continue;
		}
	  }
	  /* _a.png */
	  strcpy(pfname, "_a.png");
	  if ((fp = fopen(fname, "rb")) != nullptr) {
		tmptex = _txImage->readPNG(fp, &tmpwidth, &tmpheight, &tmpformat);
		fclose(fp);
	  }
	  if (!tmptex) {
		/* _a.bmp */
		strcpy(pfname, "_a.bmp");
		if ((fp = fopen(fname, "rb")) != nullptr) {
		  tmptex = _txImage->readBMP(fp, &tmpwidth, &tmpheight, &tmpformat);
		  fclose(fp);
		}
	  }
	  /* _rgb.png */
	  strcpy(pfname, "_rgb.png");
	  if ((fp = fopen(fname, "rb")) != nullptr) {
		tex = _txImage->readPNG(fp, &width, &height, &format);
		fclose(fp);
	  }
	  if (!tex) {
		/* _rgb.bmp */
		strcpy(pfname, "_rgb.bmp");
		if ((fp = fopen(fname, "rb")) != nullptr) {
		  tex = _txImage->readBMP(fp, &width, &height, &format);
		  fclose(fp);
		}
	  }
	  if (tmptex) {
		/* check if _rgb.* and _a.* have matching size and format. */
		if (!tex || width != tmpwidth || height != tmpheight ||
			format != graphics::internalcolorFormat::RGBA8 || tmpformat != graphics::internalcolorFormat::RGBA8) {
#if !DEBUG
		  INFO(80, wst("-----\n"));
		  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
		  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
		  if (!tex) {
			INFO(80, wst("Error: missing _rgb.*!\n"));
		  } else if (width != tmpwidth || height != tmpheight) {
			INFO(80, wst("Error: _rgb.* and _a.* have mismatched width or height!\n"));
		  } else if (format != graphics::internalcolorFormat::RGBA8 || tmpformat != graphics::internalcolorFormat::RGBA8) {
			INFO(80, wst("Error: _rgb.* or _a.* not in 32bit color!\n"));
		  }
		  if (tex) free(tex);
		  free(tmptex);
		  tex = nullptr;
		  tmptex = nullptr;
		  continue;
		}
	  }
	  /* make adjustments */
	  if (tex) {
		if (tmptex) {
		  /* merge (A)RGB and A comp */
		  DBG_INFO(80, wst("merge (A)RGB and A comp\n"));
		  int i;
		  for (i = 0; i < height * width; i++) {
#if 1
			/* use R comp for alpha. this is what Rice uses. sigh... */
			((uint32*)tex)[i] &= 0x00ffffff;
			((uint32*)tex)[i] |= ((((uint32*)tmptex)[i] & 0xff) << 24);
#endif
#if 0
			/* use libpng style grayscale conversion */
			uint32 texel = ((uint32*)tmptex)[i];
			uint32 acomp = (((texel >> 16) & 0xff) * 6969 +
							((texel >>  8) & 0xff) * 23434 +
							((texel      ) & 0xff) * 2365) / 32768;
			((uint32*)tex)[i] = (acomp << 24) | (((uint32*)tex)[i] & 0x00ffffff);
#endif
#if 0
			/* use the standard NTSC gray scale conversion */
			uint32 texel = ((uint32*)tmptex)[i];
			uint32 acomp = (((texel >> 16) & 0xff) * 299 +
							((texel >>  8) & 0xff) * 587 +
							((texel      ) & 0xff) * 114) / 1000;
			((uint32*)tex)[i] = (acomp << 24) | (((uint32*)tex)[i] & 0x00ffffff);
#endif
		  }
		  free(tmptex);
		  tmptex = nullptr;
		} else {
		  /* clobber A comp. never a question of alpha. only RGB used. */
#if !DEBUG
		  INFO(80, wst("-----\n"));
		  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
		  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
		  INFO(80, wst("Warning: missing _a.*! only using _rgb.*. treat as opaque texture.\n"));
		  int i;
		  for (i = 0; i < height * width; i++) {
			((uint32*)tex)[i] |= 0xff000000;
		  }
		}
	  }
	} else

	/*
	 * read in _all.png, _all.dds, _allciByRGBA.png, _allciByRGBA.dds
	 * _ciByRGBA.png, _ciByRGBA.dds, _ci.bmp
	 */
	if (pfname == strstr(fname, "_all.png") ||
		pfname == strstr(fname, "_all.dds") ||
#ifdef OS_WINDOWS
		pfname == strstr(fname, "_allcibyrgba.png") ||
		pfname == strstr(fname, "_allcibyrgba.dds") ||
		pfname == strstr(fname, "_cibyrgba.png") ||
		pfname == strstr(fname, "_cibyrgba.dds") ||
#else
		pfname == strstr(fname, "_allciByRGBA.png") ||
		pfname == strstr(fname, "_allciByRGBA.dds") ||
		pfname == strstr(fname, "_ciByRGBA.png") ||
		pfname == strstr(fname, "_ciByRGBA.dds") ||
#endif
		pfname == strstr(fname, "_ci.bmp")) {
	  if ((fp = fopen(fname, "rb")) != nullptr) {
		if      (strstr(fname, ".png")) tex = _txImage->readPNG(fp, &width, &height, &format);
		else                            tex = _txImage->readBMP(fp, &width, &height, &format);
		fclose(fp);
	  }
	}

	/* if we do not have a texture at this point we are screwed */
	if (!tex) {
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
	  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
	  INFO(80, wst("Error: load failed!\n"));
	  continue;
	}
	DBG_INFO(80, wst("read in as %d x %d gfmt:%x\n"), tmpwidth, tmpheight, tmpformat);

	/* check if size and format are OK */
	if (!(format == graphics::internalcolorFormat::RGBA8 || format == graphics::internalcolorFormat::COLOR_INDEX8) ||
		(width * height) < 4) { /* TxQuantize requirement: width * height must be 4 or larger. */
	  free(tex);
	  tex = nullptr;
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
	  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
	  INFO(80, wst("Error: not width * height > 4 or 8bit palette color or 32bpp or dxt1 or dxt3 or dxt5!\n"));
	  continue;
	}

	/* analyze and determine best format to quantize */
	if (format == graphics::internalcolorFormat::RGBA8) {
	  int i;
	  int alphabits = 0;
	  int fullalpha = 0;
	  boolean intensity = 1;

	  if (!(_options & LET_TEXARTISTS_FLY)) {
		/* HACK ALERT! */
		/* Account for Rice's weirdness with fmt:0 siz:2 textures.
		 * Although the conditions are relaxed with other formats,
		 * the D3D RGBA5551 surface is used for this format in certain
		 * cases. See Nintemod's SuperMario64 life gauge and power
		 * meter. The same goes for fmt:2 textures. See Mollymutt's
		 * PaperMario text. */
		if ((fmt == 0 && siz == 2) || fmt == 2) {
		  DBG_INFO(80, wst("Remove black, white, etc borders along the alpha edges.\n"));
		  /* round A comp */
		  for (i = 0; i < height * width; i++) {
			uint32 texel = ((uint32*)tex)[i];
			((uint32*)tex)[i] = ((texel & 0xff000000) == 0xff000000 ? 0xff000000 : 0) |
								(texel & 0x00ffffff);
		  }
		  /* Substitute texel color with the average of the surrounding
		   * opaque texels. This removes borders regardless of hardware
		   * texture filtering (bilinear, etc). */
		  int j;
		  for (i = 0; i < height; i++) {
			for (j = 0; j < width; j++) {
			  uint32 texel = ((uint32*)tex)[i * width + j];
			  if ((texel & 0xff000000) != 0xff000000) {
				uint32 tmptexel[8];
				uint32 k, numtexel, r, g, b;
				numtexel = r = g = b = 0;
				memset(&tmptexel, 0, sizeof(tmptexel));
				if (i > 0) {
				  tmptexel[0] = ((uint32*)tex)[(i - 1) * width + j];                        /* north */
				  if (j > 0)         tmptexel[1] = ((uint32*)tex)[(i - 1) * width + j - 1]; /* north-west */
				  if (j < width - 1) tmptexel[2] = ((uint32*)tex)[(i - 1) * width + j + 1]; /* north-east */
				}
				if (i < height - 1) {
				  tmptexel[3] = ((uint32*)tex)[(i + 1) * width + j];                        /* south */
				  if (j > 0)         tmptexel[4] = ((uint32*)tex)[(i + 1) * width + j - 1]; /* south-west */
				  if (j < width - 1) tmptexel[5] = ((uint32*)tex)[(i + 1) * width + j + 1]; /* south-east */
				}
				if (j > 0)         tmptexel[6] = ((uint32*)tex)[i * width + j - 1]; /* west */
				if (j < width - 1) tmptexel[7] = ((uint32*)tex)[i * width + j + 1]; /* east */
				for (k = 0; k < 8; k++) {
				  if ((tmptexel[k] & 0xff000000) == 0xff000000) {
					b += ((tmptexel[k] & 0x00ff0000) >> 16);
					g += ((tmptexel[k] & 0x0000ff00) >>  8);
					r += ((tmptexel[k] & 0x000000ff)      );
					numtexel++;
				  }
				}
				if (numtexel) {
				  ((uint32*)tex)[i * width + j] = ((b / numtexel) << 16) |
												  ((g / numtexel) <<  8) |
												  ((r / numtexel)      );
				} else {
				  ((uint32*)tex)[i * width + j] = texel & 0x00ffffff;
				}
			  }
			}
		  }
		}
	  }

	  /* simple analysis of texture */
	  for (i = 0; i < height * width; i++) {
		uint32 texel = ((uint32*)tex)[i];
		if (alphabits != 8) {
#if AGGRESSIVE_QUANTIZATION
		  if ((texel & 0xff000000) < 0x00000003) {
			alphabits = 1;
			fullalpha++;
		  } else if ((texel & 0xff000000) < 0xfe000000) {
			alphabits = 8;
		  }
#else
		  if ((texel & 0xff000000) == 0x00000000) {
			alphabits = 1;
			fullalpha++;
		  } else if ((texel & 0xff000000) != 0xff000000) {
			alphabits = 8;
		  }
#endif
		}
		if (intensity) {
		  int rcomp = (texel >> 16) & 0xff;
		  int gcomp = (texel >>  8) & 0xff;
		  int bcomp = (texel      ) & 0xff;
#if AGGRESSIVE_QUANTIZATION
		  if (abs(rcomp - gcomp) > 8 || abs(rcomp - bcomp) > 8 || abs(gcomp - bcomp) > 8) intensity = 0;
#else
		  if (rcomp != gcomp || rcomp != bcomp || gcomp != bcomp) intensity = 0;
#endif
		}
		if (!intensity && alphabits == 8) break;
	  }
	  DBG_INFO(80, wst("required alpha bits:%d zero acomp texels:%d rgb as intensity:%d\n"), alphabits, fullalpha, intensity);

	  /* preparations based on above analysis */
	  if (_maxbpp < 32 || _options & FORCE16BPP_HIRESTEX) {
		if      (alphabits == 0) destformat = graphics::internalcolorFormat::RGB8;
		else if (alphabits == 1) destformat = graphics::internalcolorFormat::RGB5_A1;
		else                     destformat = graphics::internalcolorFormat::RGBA8;
	  } else {
		destformat = graphics::internalcolorFormat::RGBA8;
	  }
	  if (fmt == 4 && alphabits == 0) {
		destformat = graphics::internalcolorFormat::RGBA8;
		/* Rice I format; I = (R + G + B) / 3 */
		for (i = 0; i < height * width; i++) {
		  uint32 texel = ((uint32*)tex)[i];
		  uint32 icomp = (((texel >> 16) & 0xff) +
						  ((texel >>  8) & 0xff) +
						  ((texel      ) & 0xff)) / 3;
		  ((uint32*)tex)[i] = (icomp << 24) | (texel & 0x00ffffff);
		}
	  }

	  DBG_INFO(80, wst("best gfmt:%x\n"), u32(destformat));
	}
	/*
	 * Rice hi-res textures: end */


	/* XXX: only RGBA8888 for now. comeback to this later... */
	if (format == graphics::internalcolorFormat::RGBA8) {

	  /* minification */
	  if (width > _maxwidth || height > _maxheight) {
		int ratio = 1;
		if (width / _maxwidth > height / _maxheight) {
		  ratio = (int)ceil((double)width / _maxwidth);
		} else {
		  ratio = (int)ceil((double)height / _maxheight);
		}
		if (!_txReSample->minify(&tex, &width, &height, ratio)) {
		  free(tex);
		  tex = nullptr;
		  DBG_INFO(80, wst("Error: minification failed!\n"));
		  continue;
		}
	  }

#if POW2_TEXTURES
#if (POW2_TEXTURES == 2)
		/* 3dfx Glide3x aspect ratio (8:1 - 1:8) */
		if (!_txReSample->nextPow2(&tex, &width , &height, 32, 1)) {
#else
		/* normal pow2 expansion */
		if (!_txReSample->nextPow2(&tex, &width , &height, 32, 0)) {
#endif
		  free(tex);
		  tex = nullptr;
		  DBG_INFO(80, wst("Error: aspect ratio adjustment failed!\n"));
		  continue;
		}
#endif

	  /* quantize */
	  {
		tmptex = (uint8 *)malloc(TxUtil::sizeofTx(width, height, destformat));
		if (tmptex == nullptr) {
			free(tex);
			tex = nullptr;
			result = resError;
			break;
		}
		if (destformat == graphics::internalcolorFormat::RGBA8 ||
			destformat == graphics::internalcolorFormat::RGBA4) {
			if (_maxbpp < 32 || _options & FORCE16BPP_HIRESTEX)
				destformat = graphics::internalcolorFormat::RGBA4;
		} else if (destformat == graphics::internalcolorFormat::RGB5_A1) {
			if (_maxbpp < 32 || _options & FORCE16BPP_HIRESTEX)
				destformat = graphics::internalcolorFormat::RGB5_A1;
		}
		if (_txQuantize->quantize(tex, tmptex, width, height, graphics::internalcolorFormat::RGBA8, destformat, 0)) {
			format = destformat;
			free(tex);
			tex = tmptex;
		} else
			free(tmptex);
		tmptex = nullptr;
	  }
	}


	/* last minute validations */
	if (!tex || !chksum || !width || !height || format == graphics::internalcolorFormat::NOCOLOR || width > _maxwidth || height > _maxheight) {
#if !DEBUG
	  INFO(80, wst("-----\n"));
	  INFO(80, wst("path: %ls\n"), dir_path.string().c_str());
	  INFO(80, wst("file: %ls\n"), it->path().leaf().c_str());
#endif
	  if (tex) {
		free(tex);
		tex = nullptr;
		INFO(80, wst("Error: bad format or size! %d x %d gfmt:%x\n"), width, height, u32(format));
	  } else {
		INFO(80, wst("Error: load failed!!\n"));
	  }
	  continue;
	}

	/* load it into hires texture cache. */
	{
	  uint64 chksum64 = (uint64)palchksum;
	  chksum64 <<= 32;
	  chksum64 |= (uint64)chksum;

	  GHQTexInfo tmpInfo;
	  tmpInfo.data = tex;
	  tmpInfo.width = width;
	  tmpInfo.height = height;
	  tmpInfo.is_hires_tex = 1;
	  setTextureFormat(format, &tmpInfo);

	  /* remove redundant in cache */
	  if (replace && TxCache::del(chksum64)) {
		DBG_INFO(80, wst("removed duplicate old cache.\n"));
	  }

	  /* add to cache */
	  const boolean added = TxCache::add(chksum64, &tmpInfo);
	  free(tex);
	  if (added) {
		/* Callback to display hires texture info.
		 * Gonetz <gonetz(at)ngs.ru> */
		if (_callback) {
		  wchar_t tmpbuf[MAX_PATH];
		  mbstowcs(tmpbuf, fname, MAX_PATH);
		  (*_callback)(wst("[%d] total mem:%.2fmb - %ls\n"), _cache.size(), (float)_totalSize/1000000, tmpbuf);
		}
		DBG_INFO(80, wst("texture loaded!\n"));
	  } else {
		  result = resError;
		  break;
	  }
	}

  } while (foundfilename != nullptr);
  osal_search_dir_close(dir);

  CHDIR(curpath);

  return result;
}
