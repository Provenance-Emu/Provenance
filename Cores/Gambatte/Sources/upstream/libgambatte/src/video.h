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

#ifndef VIDEO_H
#define VIDEO_H

#include "interruptrequester.h"
#include "minkeeper.h"
#include "osd_element.h"
#include "scoped_ptr.h"
#include "video/lyc_irq.h"
#include "video/m0_irq.h"
#include "video/next_m0_time.h"
#include "video/ppu.h"

namespace gambatte {

class VideoInterruptRequester {
public:
	explicit VideoInterruptRequester(InterruptRequester &intreq)
	: intreq_(intreq)
	{
	}

	void flagHdmaReq() const { gambatte::flagHdmaReq(intreq_); }
	void flagIrq(unsigned bit) const { intreq_.flagIrq(bit); }
	void setNextEventTime(unsigned long time) const { intreq_.setEventTime<intevent_video>(time); }

private:
	InterruptRequester &intreq_;
};

class LCD {
public:
	LCD(unsigned char const *oamram, unsigned char const *vram,
	    VideoInterruptRequester memEventRequester);
	void reset(unsigned char const *oamram, unsigned char const *vram, bool cgb);
	void setStatePtrs(SaveState &state);
	void saveState(SaveState &state) const;
	void loadState(SaveState const &state, unsigned char const *oamram);
	void setDmgPaletteColor(unsigned palNum, unsigned colorNum, unsigned long rgb32);
	void setVideoBuffer(uint_least32_t *videoBuf, std::ptrdiff_t pitch);
	void setOsdElement(transfer_ptr<OsdElement> osdElement) { osdElement_ = osdElement; }

	void dmgBgPaletteChange(unsigned data, unsigned long cycleCounter) {
		update(cycleCounter);
		bgpData_[0] = data;
		setDmgPalette(ppu_.bgPalette(), dmgColorsRgb32_, data);
	}

	void dmgSpPalette1Change(unsigned data, unsigned long cycleCounter) {
		update(cycleCounter);
		objpData_[0] = data;
		setDmgPalette(ppu_.spPalette(), dmgColorsRgb32_ + 4, data);
	}

	void dmgSpPalette2Change(unsigned data, unsigned long cycleCounter) {
		update(cycleCounter);
		objpData_[1] = data;
		setDmgPalette(ppu_.spPalette() + 4, dmgColorsRgb32_ + 8, data);
	}

	void cgbBgColorChange(unsigned index, unsigned data, unsigned long cycleCounter) {
		if (bgpData_[index] != data)
			doCgbBgColorChange(index, data, cycleCounter);
	}

	void cgbSpColorChange(unsigned index, unsigned data, unsigned long cycleCounter) {
		if (objpData_[index] != data)
			doCgbSpColorChange(index, data, cycleCounter);
	}

	unsigned cgbBgColorRead(unsigned index, unsigned long cycleCounter) {
		return ppu_.cgb() & cgbpAccessible(cycleCounter) ? bgpData_[index] : 0xFF;
	}

	unsigned cgbSpColorRead(unsigned index, unsigned long cycleCounter) {
		return ppu_.cgb() & cgbpAccessible(cycleCounter) ? objpData_[index] : 0xFF;
	}

	void updateScreen(bool blanklcd, unsigned long cc);
	void resetCc(unsigned long oldCC, unsigned long newCc);
	void speedChange(unsigned long cycleCounter);
	bool vramAccessible(unsigned long cycleCounter);
	bool oamReadable(unsigned long cycleCounter);
	bool oamWritable(unsigned long cycleCounter);
	void wxChange(unsigned newValue, unsigned long cycleCounter);
	void wyChange(unsigned newValue, unsigned long cycleCounter);
	void oamChange(unsigned long cycleCounter);
	void oamChange(const unsigned char *oamram, unsigned long cycleCounter);
	void scxChange(unsigned newScx, unsigned long cycleCounter);
	void scyChange(unsigned newValue, unsigned long cycleCounter);
	void vramChange(unsigned long cycleCounter) { update(cycleCounter); }
	unsigned getStat(unsigned lycReg, unsigned long cycleCounter);

	unsigned getLyReg(unsigned long const cc) {
		unsigned lyReg = 0;

		if (ppu_.lcdc() & lcdc_en) {
			if (cc >= ppu_.lyCounter().time())
				update(cc);

			lyReg = ppu_.lyCounter().ly();

			if (lyReg == 153) {
				if (isDoubleSpeed()) {
					if (ppu_.lyCounter().time() - cc <= 456 * 2 - 8)
						lyReg = 0;
				} else
					lyReg = 0;
			} else if (ppu_.lyCounter().time() - cc <= 4)
				++lyReg;
		}

		return lyReg;
	}

	unsigned long nextMode1IrqTime() const { return eventTimes_(memevent_m1irq); }
	void lcdcChange(unsigned data, unsigned long cycleCounter);
	void lcdstatChange(unsigned data, unsigned long cycleCounter);
	void lycRegChange(unsigned data, unsigned long cycleCounter);
	void enableHdma(unsigned long cycleCounter);
	void disableHdma(unsigned long cycleCounter);
	bool hdmaIsEnabled() const { return eventTimes_(memevent_hdma) != disabled_time; }
	void update(unsigned long cycleCounter);
	bool isCgb() const { return ppu_.cgb(); }
	bool isDoubleSpeed() const { return ppu_.lyCounter().isDoubleSpeed(); }

private:
	enum Event { event_mem,
	             event_ly, event_last = event_ly };

	enum MemEvent { memevent_oneshot_statirq,
	                memevent_oneshot_updatewy2,
	                memevent_m1irq,
	                memevent_lycirq,
	                memevent_spritemap,
	                memevent_hdma,
	                memevent_m2irq,
	                memevent_m0irq, memevent_last = memevent_m0irq };

	enum { num_events = event_last + 1 };
	enum { num_memevents = memevent_last + 1 };

	class EventTimes {
	public:
		explicit EventTimes(VideoInterruptRequester memEventRequester)
		: eventMin_(disabled_time)
		, memEventMin_(disabled_time)
		, memEventRequester_(memEventRequester)
		{
		}

		Event nextEvent() const { return static_cast<Event>(eventMin_.min()); }
		unsigned long nextEventTime() const { return eventMin_.minValue(); }
		unsigned long operator()(Event e) const { return eventMin_.value(e); }
		template<Event e> void set(unsigned long time) { eventMin_.setValue<e>(time); }
		void set(Event e, unsigned long time) { eventMin_.setValue(e, time); }

		MemEvent nextMemEvent() const { return static_cast<MemEvent>(memEventMin_.min()); }
		unsigned long nextMemEventTime() const { return memEventMin_.minValue(); }
		unsigned long operator()(MemEvent e) const { return memEventMin_.value(e); }

		template<MemEvent e>
		void setm(unsigned long time) { memEventMin_.setValue<e>(time); setMemEvent(); }
		void set(MemEvent e, unsigned long time) { memEventMin_.setValue(e, time); setMemEvent(); }

		void flagIrq(unsigned bit) { memEventRequester_.flagIrq(bit); }
		void flagHdmaReq() { memEventRequester_.flagHdmaReq(); }

	private:
		MinKeeper<num_events> eventMin_;
		MinKeeper<num_memevents> memEventMin_;
		VideoInterruptRequester memEventRequester_;

		void setMemEvent() {
			unsigned long nmet = nextMemEventTime();
			eventMin_.setValue<event_mem>(nmet);
			memEventRequester_.setNextEventTime(nmet);
		}
	};

	PPU ppu_;
	unsigned long dmgColorsRgb32_[3 * 4];
	unsigned char  bgpData_[8 * 8];
	unsigned char objpData_[8 * 8];
	EventTimes eventTimes_;
	M0Irq m0Irq_;
	LycIrq lycIrq_;
	NextM0Time nextM0Time_;
	scoped_ptr<OsdElement> osdElement_;
	unsigned char statReg_;
	unsigned char m2IrqStatReg_;
	unsigned char m1IrqStatReg_;

	static void setDmgPalette(unsigned long palette[],
	                          unsigned long const dmgColors[],
	                          unsigned data);
	void refreshPalettes();
	void setDBuffer();
	void doMode2IrqEvent();
	void event();
	unsigned long m0TimeOfCurrentLine(unsigned long cc);
	bool cgbpAccessible(unsigned long cycleCounter);
	bool lycRegChangeStatTriggerBlockedByM0OrM1Irq(unsigned long cc);
	bool lycRegChangeTriggersStatIrq(unsigned old, unsigned data, unsigned long cc);
	bool statChangeTriggersM0LycOrM1StatIrqCgb(unsigned old, unsigned data, unsigned long cc);
	bool statChangeTriggersStatIrqCgb(unsigned old, unsigned data, unsigned long cc);
	bool statChangeTriggersStatIrqDmg(unsigned old, unsigned long cc);
	bool statChangeTriggersStatIrq(unsigned old, unsigned data, unsigned long cc);
	void mode3CyclesChange();
	void doCgbBgColorChange(unsigned index, unsigned data, unsigned long cycleCounter);
	void doCgbSpColorChange(unsigned index, unsigned data, unsigned long cycleCounter);
};

}

#endif
