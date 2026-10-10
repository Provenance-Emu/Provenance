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

#include "rtc.h"
#include "../savestate.h"

namespace gambatte {

Rtc::Rtc()
: activeData_(0)
, activeSet_(0)
, baseTime_(0)
, haltTime_(0)
, index_(5)
, dataDh_(0)
, dataDl_(0)
, dataH_(0)
, dataM_(0)
, dataS_(0)
, enabled_(false)
, lastLatchData_(false)
{
}

void Rtc::doLatch() {
	std::time_t tmp = (dataDh_ & 0x40 ? haltTime_ : std::time(0)) - baseTime_;

	while (tmp > 0x1FF * 86400) {
		baseTime_ += 0x1FF * 86400;
		tmp -= 0x1FF * 86400;
		dataDh_ |= 0x80;
	}

	dataDl_ = (tmp / 86400) & 0xFF;
	dataDh_ &= 0xFE;
	dataDh_ |= ((tmp / 86400) & 0x100) >> 8;
	tmp %= 86400;

	dataH_ = tmp / 3600;
	tmp %= 3600;

	dataM_ = tmp / 60;
	tmp %= 60;

	dataS_ = tmp;
}

void Rtc::doSwapActive() {
	if (!enabled_ || index_ > 4) {
		activeData_ = 0;
		activeSet_ = 0;
	} else switch (index_) {
	case 0x00:
		activeData_ = &dataS_;
		activeSet_ = &Rtc::setS;
		break;
	case 0x01:
		activeData_ = &dataM_;
		activeSet_ = &Rtc::setM;
		break;
	case 0x02:
		activeData_ = &dataH_;
		activeSet_ = &Rtc::setH;
		break;
	case 0x03:
		activeData_ = &dataDl_;
		activeSet_ = &Rtc::setDl;
		break;
	case 0x04:
		activeData_ = &dataDh_;
		activeSet_ = &Rtc::setDh;
		break;
	}
}

void Rtc::saveState(SaveState &state) const {
	state.rtc.baseTime = baseTime_;
	state.rtc.haltTime = haltTime_;
	state.rtc.dataDh = dataDh_;
	state.rtc.dataDl = dataDl_;
	state.rtc.dataH = dataH_;
	state.rtc.dataM = dataM_;
	state.rtc.dataS = dataS_;
	state.rtc.lastLatchData = lastLatchData_;
}

void Rtc::loadState(SaveState const &state) {
	baseTime_ = state.rtc.baseTime;
	haltTime_ = state.rtc.haltTime;
	dataDh_ = state.rtc.dataDh;
	dataDl_ = state.rtc.dataDl;
	dataH_ = state.rtc.dataH;
	dataM_ = state.rtc.dataM;
	dataS_ = state.rtc.dataS;
	lastLatchData_ = state.rtc.lastLatchData;
	doSwapActive();
}

void Rtc::setDh(unsigned const newDh) {
	std::time_t const unixtime = dataDh_ & 0x40 ? haltTime_ : std::time(0);
	std::time_t const oldHighdays = ((unixtime - baseTime_) / 86400) & 0x100;
	baseTime_ += oldHighdays * 86400;
	baseTime_ -= ((newDh & 0x1) << 8) * 86400;

	if ((dataDh_ ^ newDh) & 0x40) {
		if (newDh & 0x40)
			haltTime_ = std::time(0);
		else
			baseTime_ += std::time(0) - haltTime_;
	}
}

void Rtc::setDl(unsigned const newLowdays) {
	std::time_t const unixtime = dataDh_ & 0x40 ? haltTime_ : std::time(0);
	std::time_t const oldLowdays = ((unixtime - baseTime_) / 86400) & 0xFF;
	baseTime_ += oldLowdays * 86400;
	baseTime_ -= newLowdays * 86400;
}

void Rtc::setH(unsigned const newHours) {
	std::time_t const unixtime = dataDh_ & 0x40 ? haltTime_ : std::time(0);
	std::time_t const oldHours = ((unixtime - baseTime_) / 3600) % 24;
	baseTime_ += oldHours * 3600;
	baseTime_ -= newHours * 3600;
}

void Rtc::setM(unsigned const newMinutes) {
	std::time_t const unixtime = dataDh_ & 0x40 ? haltTime_ : std::time(0);
	std::time_t const oldMinutes = ((unixtime - baseTime_) / 60) % 60;
	baseTime_ += oldMinutes * 60;
	baseTime_ -= newMinutes * 60;
}

void Rtc::setS(unsigned const newSeconds) {
	std::time_t const unixtime = dataDh_ & 0x40 ? haltTime_ : std::time(0);
	baseTime_ += (unixtime - baseTime_) % 60;
	baseTime_ -= newSeconds;
}

}
