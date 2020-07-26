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

#include "portable.h"
#include "iiostrm.h"

HRESULT ISequentialInStream::Read(void *aData, UINT32 aSize, UINT32* aProcessedSize) {
	if (aSize > size)
		aSize = size;
	*aProcessedSize = aSize;
	memcpy(aData, data, aSize);
	size -= aSize;
	data += aSize;
	return S_OK;
}

HRESULT ISequentialOutStream::Write(const void *aData, UINT32 aSize, UINT32* aProcessedSize) {
	if (aSize > size) {
		overflow = true;
		aSize = size;
	}
	*aProcessedSize = aSize;
	memcpy(data, aData, aSize);
	size -= aSize;
	data += aSize;
	total += aSize;
	return S_OK;
}
