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

#define DBG_LEVEL 80

#include "TxDbg.h"
#include <stdarg.h>
#include <stdio.h>

#include <Foundation/Foundation.h>

TxDbg::TxDbg()
{
	_level = DBG_LEVEL;
}

TxDbg::~TxDbg()
{}

void
TxDbg::output(const int level, const wchar_t *format, ...)
{
    if (level > _level)
		return;

	va_list va;

    NSString *nsformat = [[NSString alloc] initWithBytes:format
                                                  length:wcslen(format)*sizeof(*format)
                                                encoding:NSUTF32LittleEndianStringEncoding];

    nsformat = [@"GLideN64: " stringByAppendingString:nsformat];

	va_start(va, format);
	NSLogv(nsformat, va);
	va_end(va);
}
