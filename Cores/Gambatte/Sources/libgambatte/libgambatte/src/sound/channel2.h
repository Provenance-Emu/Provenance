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

#ifndef SOUND_CHANNEL2_H
#define SOUND_CHANNEL2_H

#include "duty_unit.h"
#include "envelope_unit.h"
#include "gbint.h"
#include "length_counter.h"
#include "static_output_tester.h"

namespace gambatte {

struct SaveState;

class Channel2 {
public:
	Channel2();
	void setNr1(unsigned data);
	void setNr2(unsigned data);
	void setNr3(unsigned data);
	void setNr4(unsigned data);
	void setSo(unsigned long soMask);
	bool isActive() const { return master_; }
	void update(uint_least32_t *buf, unsigned long soBaseVol, unsigned long cycles);
	void reset();
	void saveState(SaveState &state);
	void loadState(SaveState const &state);

private:
	friend class StaticOutputTester<Channel2, DutyUnit>;

	StaticOutputTester<Channel2, DutyUnit> staticOutputTest_;
	DutyMasterDisabler disableMaster_;
	LengthCounter lengthCounter_;
	DutyUnit dutyUnit_;
	EnvelopeUnit envelopeUnit_;
	SoundUnit *nextEventUnit;
	unsigned long cycleCounter_;
	unsigned long soMask_;
	unsigned long prevOut_;
	unsigned char nr4_;
	bool master_;

	void setEvent();
};

}

#endif
