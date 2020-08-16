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

#include "envelope_unit.h"
#include <algorithm>

namespace gambatte {

EnvelopeUnit::VolOnOffEvent EnvelopeUnit::nullEvent_;

EnvelopeUnit::EnvelopeUnit(VolOnOffEvent &volOnOffEvent)
: volOnOffEvent_(volOnOffEvent)
, nr2_(0)
, volume_(0)
{
}

void EnvelopeUnit::reset() {
	counter_ = counter_disabled;
}

void EnvelopeUnit::saveState(SaveState::SPU::Env &estate) const {
	estate.counter = counter_;
	estate.volume = volume_;
}

void EnvelopeUnit::loadState(SaveState::SPU::Env const &estate, unsigned nr2, unsigned long cc) {
	counter_ = std::max(estate.counter, cc);
	volume_ = estate.volume;
	nr2_ = nr2;
}

void EnvelopeUnit::event() {
	unsigned long const period = nr2_ & 7;

	if (period) {
		unsigned newVol = volume_;
		if (nr2_ & 8)
			++newVol;
		else
			--newVol;

		if (newVol < 0x10U) {
			volume_ = newVol;
			if (volume_ < 2)
				volOnOffEvent_(counter_);

			counter_ += period << 15;
		} else
			counter_ = counter_disabled;
	} else
		counter_ += 8ul << 15;
}

bool EnvelopeUnit::nr2Change(unsigned const newNr2) {
	if (!(nr2_ & 7) && counter_ != counter_disabled)
		++volume_;
	else if (!(nr2_ & 8))
		volume_ += 2;

	if ((nr2_ ^ newNr2) & 8)
		volume_ = 0x10 - volume_;

	volume_ &= 0xF;
	nr2_ = newNr2;
	return !(newNr2 & 0xF8);
}

bool EnvelopeUnit::nr4Init(unsigned long const cc) {
	unsigned long period = nr2_ & 7 ? nr2_ & 7 : 8;

	if (((cc + 2) & 0x7000) == 0x0000)
		++period;

	counter_ = cc - ((cc - 0x1000) & 0x7FFF) + period * 0x8000;

	volume_ = nr2_ >> 4;
	return !(nr2_ & 0xF8);
}

}
