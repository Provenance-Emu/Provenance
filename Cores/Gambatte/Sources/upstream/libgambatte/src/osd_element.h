//
//   Copyright (C) 2008 by sinamas <sinamas at users.sourceforge.net>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License version 2 for more details.
//
//   You should have received a copy of the GNU General Public License
//   version 2 along with this program; if not, write to the
//   Free Software Foundation, Inc.,
//   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#ifndef OSD_ELEMENT_H
#define OSD_ELEMENT_H

#include "gbint.h"

namespace gambatte {

class OsdElement {
public:
	enum Opacity { seven_eighths, three_fourths };
	enum { pixel_transparent = 0xfffffffful };

	virtual ~OsdElement() {}
	unsigned x() const { return x_; }
	unsigned y() const { return y_; }
	unsigned w() const { return w_; }
	unsigned h() const { return h_; }
	Opacity opacity() const { return opacity_; }
	virtual uint_least32_t const * update() = 0;

protected:
	explicit OsdElement(unsigned x = 0, unsigned y = 0, unsigned w = 0, unsigned h = 0,
	                    Opacity opacity = seven_eighths)
	: opacity_(opacity), x_(x), y_(y), w_(w), h_(h)
	{
	}

	void setPos(unsigned x, unsigned y) {
		x_ = x;
		y_ = y;
	}

	void setSize(unsigned w, unsigned h) {
		w_ = w;
		h_ = h;
	}

	void setOpacity(Opacity opacity) { opacity_ = opacity; }

private:
	Opacity opacity_;
	unsigned x_;
	unsigned y_;
	unsigned w_;
	unsigned h_;
};

}

#endif
