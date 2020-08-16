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

#ifndef STATIC_OUTPUT_TESTER_H
#define STATIC_OUTPUT_TESTER_H

#include "envelope_unit.h"

namespace gambatte {

template<class Channel, class Unit>
class StaticOutputTester : public EnvelopeUnit::VolOnOffEvent {
public:
	StaticOutputTester(Channel const &ch, Unit &unit) : ch_(ch), unit_(unit) {}
	void operator()(unsigned long cc);

private:
	Channel const &ch_;
	Unit &unit_;
};

template<class Channel, class Unit>
void StaticOutputTester<Channel, Unit>::operator()(unsigned long cc) {
	if (ch_.soMask_ && ch_.master_ && ch_.envelopeUnit_.getVolume())
		unit_.reviveCounter(cc);
	else
		unit_.killCounter();
}

}

#endif
