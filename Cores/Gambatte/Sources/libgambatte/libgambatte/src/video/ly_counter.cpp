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

#include "ly_counter.h"
#include "../savestate.h"

namespace gambatte {

LyCounter::LyCounter()
: time_(0)
, lineTime_(0)
, ly_(0)
, ds_(false)
{
	setDoubleSpeed(false);
	reset(0, 0);
}

void LyCounter::doEvent() {
	++ly_;
	if (ly_ == 154)
		ly_ = 0;

	time_ = time_ + lineTime_;
}

unsigned long LyCounter::nextLineCycle(unsigned const lineCycle, unsigned long const cc) const {
	unsigned long tmp = time_ + (lineCycle << ds_);
	if (tmp - cc > lineTime_)
		tmp -= lineTime_;

	return tmp;
}

unsigned long LyCounter::nextFrameCycle(unsigned long const frameCycle, unsigned long const cc) const {
	unsigned long tmp = time_ + (((153U - ly()) * 456U + frameCycle) << ds_);
	if (tmp - cc > 70224U << ds_)
		tmp -= 70224U << ds_;

	return tmp;
}

void LyCounter::reset(unsigned long videoCycles, unsigned long lastUpdate) {
	ly_ = videoCycles / 456;
	time_ = lastUpdate + ((456 - (videoCycles - ly_ * 456ul)) << isDoubleSpeed());
}

void LyCounter::setDoubleSpeed(bool ds) {
	ds_ = ds;
	lineTime_ = 456U << ds;
}

}
