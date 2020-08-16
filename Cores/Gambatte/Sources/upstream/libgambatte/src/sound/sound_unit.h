//
//   Copyright (C) 2007 by sinamas <sinamas at users.sourceforge.net>
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

#ifndef SOUND_UNIT_H
#define SOUND_UNIT_H

namespace gambatte {

class SoundUnit {
public:
	enum { counter_max = 0x80000000u, counter_disabled = 0xFFFFFFFFu };

	virtual ~SoundUnit() {}
	virtual void event() = 0;

	virtual void resetCounters(unsigned long /*oldCc*/) {
		if (counter_ != counter_disabled)
			counter_ -= counter_max;
	}

	unsigned long counter() const { return counter_; }

protected:
	SoundUnit() : counter_(counter_disabled) {}
	unsigned long counter_;
};

}

#endif
