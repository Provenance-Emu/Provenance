/*
Copyright (C) 2002 Andrea Mazzoleni ( http://advancemame.sf.net )
Copyright (C) 2001-4 Igor Pavlov ( http://www.7-zip.org )

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef __IINOUTSTREAMS_H
#define __IINOUTSTREAMS_H

#include "portable.h"

class ISequentialInStream
{
	const char* data;
	unsigned size;
public:
	ISequentialInStream(const char* Adata, unsigned Asize) : data(Adata), size(Asize) { }

	HRESULT Read(void *aData, UINT32 aSize, UINT32 *aProcessedSize);
};

class ISequentialOutStream
{
	char* data;
	unsigned size;
	bool overflow;
	unsigned total;
public:
	ISequentialOutStream(char* Adata, unsigned Asize) : data(Adata), size(Asize), overflow(false), total(0) { }

	bool overflow_get() const { return overflow; }
	unsigned size_get() const { return total; }

	HRESULT Write(const void *aData, UINT32 aSize, UINT32 *aProcessedSize);
};

#endif
