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

#ifndef TIMA_H
#define TIMA_H

#include "interruptrequester.h"

namespace gambatte {

class TimaInterruptRequester {
public:
	explicit TimaInterruptRequester(InterruptRequester &intreq) : intreq_(intreq) {}
	void flagIrq() const { intreq_.flagIrq(4); }
	unsigned long nextIrqEventTime() const { return intreq_.eventTime(intevent_tima); }
	void setNextIrqEventTime(unsigned long time) const { intreq_.setEventTime<intevent_tima>(time); }

private:
	InterruptRequester &intreq_;
};

class Tima {
public:
	Tima();
	void saveState(SaveState &) const;
	void loadState(const SaveState &, TimaInterruptRequester timaIrq);
	void resetCc(unsigned long oldCc, unsigned long newCc, TimaInterruptRequester timaIrq);
	void setTima(unsigned tima, unsigned long cc, TimaInterruptRequester timaIrq);
	void setTma(unsigned tma, unsigned long cc, TimaInterruptRequester timaIrq);
	void setTac(unsigned tac, unsigned long cc, TimaInterruptRequester timaIrq);
	unsigned tima(unsigned long cc);
	void doIrqEvent(TimaInterruptRequester timaIrq);

private:
	unsigned long lastUpdate_;
	unsigned long tmatime_;
	unsigned char tima_;
	unsigned char tma_;
	unsigned char tac_;

	void updateIrq(unsigned long const cc, TimaInterruptRequester timaIrq) {
		while (cc >= timaIrq.nextIrqEventTime())
			doIrqEvent(timaIrq);
	}

	void updateTima(unsigned long cc);
};

}

#endif
