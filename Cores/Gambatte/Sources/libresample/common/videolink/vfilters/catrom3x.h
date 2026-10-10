/***************************************************************************
 *   Copyright (C) 2009 by Sindre Aamås                                    *
 *   sinamas@users.sourceforge.net                                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License version 2 as     *
 *   published by the Free Software Foundation.                            *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License version 2 for more details.                *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   version 2 along with this program; if not, write to the               *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
#ifndef CATROM3X_H
#define CATROM3X_H

#include "../videolink.h"
#include "../vfilterinfo.h"
#include "array.h"
#include "gbint.h"

class Catrom3x : public VideoLink {
public:
	enum { out_width  = VfilterInfo::in_width  * 3 };
	enum { out_height = VfilterInfo::in_height * 3 };

	Catrom3x();
	virtual void * inBuf() const;
	virtual std::ptrdiff_t inPitch() const;
	virtual void draw(void *dst, std::ptrdiff_t dstpitch);

private:
	Array<gambatte::uint_least32_t> const buffer_;
};

#endif
