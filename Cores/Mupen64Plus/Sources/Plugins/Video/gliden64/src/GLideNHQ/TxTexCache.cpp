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

#ifdef __MSC__
#pragma warning(disable: 4786)
#endif

#include "TxTexCache.h"
#include "TxDbg.h"
#include <osal_files.h>
#include <zlib.h>

TxTexCache::~TxTexCache()
{
}

TxTexCache::TxTexCache(int options, int cachesize, const wchar_t *cachePath, const wchar_t *ident,
					   dispInfoFuncExt callback
					   ) : TxCache((options & ~GZ_HIRESTEXCACHE), cachesize, cachePath, ident, callback)
{
	/* assert local options */
	if (_cachePath.empty() || _ident.empty() || !_cacheSize)
		_options &= ~DUMP_TEXCACHE;

	_cacheDumped = 0;

	if (_options & DUMP_TEXCACHE) {
		/* find it on disk */
		_cacheDumped = TxCache::load(_cachePath.c_str(), _getFileName().c_str(), _getConfig(), 0);
	}
}

boolean
TxTexCache::add(uint64 checksum, GHQTexInfo *info)
{
	if (_cacheSize <= 0)
		return 0;

	const boolean res = TxCache::add(checksum, info);
	if (res)
		_cacheDumped = 0;
	return res;
}

void
TxTexCache::dump()
{
	if ((_options & DUMP_TEXCACHE) && !_cacheDumped) {
		/* dump cache to disk */
		_cacheDumped = TxCache::save(_cachePath.c_str(), _getFileName().c_str(), _getConfig());
	}
}

tx_wstring TxTexCache::_getFileName() const
{
	tx_wstring filename = _ident + wst("_MEMORYCACHE.") + TEXCACHE_EXT;
	removeColon(filename);
	return filename;
}

int TxTexCache::_getConfig() const
{
	return _options & (FILTER_MASK | ENHANCEMENT_MASK | FORCE16BPP_TEX | GZ_TEXCACHE);
}
