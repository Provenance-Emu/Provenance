//
//   Copyright (C) 2010 by sinamas <sinamas at users.sourceforge.net>
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

#ifndef INTERRUPT_REQUESTER_H
#define INTERRUPT_REQUESTER_H

#include "counterdef.h"
#include "minkeeper.h"

namespace gambatte {

struct SaveState;

enum IntEventId { intevent_unhalt,
                  intevent_end,
                  intevent_blit,
                  intevent_serial,
                  intevent_oam,
                  intevent_dma,
                  intevent_tima,
                  intevent_video,
                  intevent_interrupts, intevent_last = intevent_interrupts };

class InterruptRequester {
public:
	InterruptRequester();
	void saveState(SaveState &) const;
	void loadState(SaveState const &);
	void resetCc(unsigned long oldCc, unsigned long newCc);
	unsigned ifreg() const { return ifreg_; }
	unsigned pendingIrqs() const { return ifreg_ & iereg_; }
	bool ime() const { return intFlags_.ime(); }
	bool halted() const { return intFlags_.halted(); }
	void ei(unsigned long cc);
	void di();
	void halt();
	void unhalt();
	void flagIrq(unsigned bit);
	void ackIrq(unsigned bit);
	void setIereg(unsigned iereg);
	void setIfreg(unsigned ifreg);

	IntEventId minEventId() const { return static_cast<IntEventId>(eventTimes_.min()); }
	unsigned long minEventTime() const { return eventTimes_.minValue(); }
	template<IntEventId id> void setEventTime(unsigned long value) { eventTimes_.setValue<id>(value); }
	void setEventTime(IntEventId id, unsigned long value) { eventTimes_.setValue(id, value); }
	unsigned long eventTime(IntEventId id) const { return eventTimes_.value(id); }

private:
	class IntFlags {
	public:
		IntFlags() : flags_(0) {}
		bool ime() const { return flags_ & flag_ime; }
		bool halted() const { return flags_ & flag_halted; }
		bool imeOrHalted() const { return flags_; }
		void setIme() { flags_ |= flag_ime; }
		void unsetIme() { flags_ &= ~flag_ime; }
		void setHalted() { flags_ |= flag_halted; }
		void unsetHalted() { flags_ &= ~flag_halted; }
		void set(bool ime, bool halted) { flags_ = halted * flag_halted + ime * flag_ime; }

	private:
		unsigned char flags_;
		enum { flag_ime = 1, flag_halted = 2 };
	};

	MinKeeper<intevent_last + 1> eventTimes_;
	unsigned long minIntTime_;
	unsigned ifreg_;
	unsigned iereg_;
	IntFlags intFlags_;
};

inline void flagHdmaReq(InterruptRequester &intreq) { intreq.setEventTime<intevent_dma>(0); }
inline void flagGdmaReq(InterruptRequester &intreq) { intreq.setEventTime<intevent_dma>(1); }
inline void ackDmaReq(InterruptRequester &intreq) { intreq.setEventTime<intevent_dma>(disabled_time); }
inline bool hdmaReqFlagged(InterruptRequester const &intreq) { return intreq.eventTime(intevent_dma) == 0; }
inline bool gdmaReqFlagged(InterruptRequester const &intreq) { return intreq.eventTime(intevent_dma) == 1; }

}

#endif
