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

#include "video.h"
#include "savestate.h"
#include <algorithm>
#include <cstring>

namespace gambatte {

void LCD::setDmgPalette(unsigned long palette[], unsigned long const dmgColors[], unsigned data) {
	palette[0] = dmgColors[data      & 3];
	palette[1] = dmgColors[data >> 2 & 3];
	palette[2] = dmgColors[data >> 4 & 3];
	palette[3] = dmgColors[data >> 6 & 3];
}

static unsigned long gbcToRgb32(unsigned const bgr15) {
	unsigned long const r = bgr15       & 0x1F;
	unsigned long const g = bgr15 >>  5 & 0x1F;
	unsigned long const b = bgr15 >> 10 & 0x1F;

	return ((r * 13 + g * 2 + b) >> 1) << 16
	     | (g * 3 + b) << 9
	     | (r * 3 + g * 2 + b * 11) >> 1;
}

/*static unsigned long gbcToRgb16(unsigned const bgr15) {
	unsigned const r = bgr15 & 0x1F;
	unsigned const g = bgr15 >> 5 & 0x1F;
	unsigned const b = bgr15 >> 10 & 0x1F;

	return (((r * 13 + g * 2 + b + 8) << 7) & 0xF800)
	     | ((g * 3 + b + 1) >> 1) << 5
	     | ((r * 3 + g * 2 + b * 11 + 8) >> 4);
}

static unsigned long gbcToUyvy(unsigned const bgr15) {
	unsigned const r5 = bgr15 & 0x1F;
	unsigned const g5 = bgr15 >> 5 & 0x1F;
	unsigned const b5 = bgr15 >> 10 & 0x1F;

	// y = (r5 * 926151 + g5 * 1723530 + b5 * 854319) / 510000 + 16;
	// u = (b5 * 397544 - r5 * 68824 - g5 * 328720) / 225930 + 128;
	// v = (r5 * 491176 - g5 * 328720 - b5 * 162456) / 178755 + 128;

	unsigned long const y = (r5 * 116 + g5 * 216 + b5 * 107 + 16 * 64 + 32) >> 6;
	unsigned long const u = (b5 * 225 - r5 * 39 - g5 * 186 + 128 * 128 + 64) >> 7;
	unsigned long const v = (r5 * 176 - g5 * 118 - b5 * 58 + 128 * 64 + 32) >> 6;

#ifdef WORDS_BIGENDIAN
	return u << 24 | y << 16 | v << 8 | y;
#else
	return y << 24 | v << 16 | y << 8 | u;
#endif
}*/

LCD::LCD(unsigned char const *oamram, unsigned char const *vram,
         VideoInterruptRequester memEventRequester)
: ppu_(nextM0Time_, oamram, vram)
, eventTimes_(memEventRequester)
, statReg_(0)
, m2IrqStatReg_(0)
, m1IrqStatReg_(0)
{
	std::memset( bgpData_, 0, sizeof  bgpData_);
	std::memset(objpData_, 0, sizeof objpData_);

	for (std::size_t i = 0; i < sizeof dmgColorsRgb32_ / sizeof dmgColorsRgb32_[0]; ++i)
		dmgColorsRgb32_[i] = (3 - (i & 3)) * 85 * 0x010101ul;

	reset(oamram, vram, false);
	setVideoBuffer(0, 160);
}

void LCD::reset(unsigned char const *oamram, unsigned char const *vram, bool cgb) {
	ppu_.reset(oamram, vram, cgb);
	lycIrq_.setCgb(cgb);
	refreshPalettes();
}

static unsigned long mode2IrqSchedule(unsigned const statReg,
		LyCounter const &lyCounter, unsigned long const cc) {
	if (!(statReg & lcdstat_m2irqen))
		return disabled_time;

	int next = lyCounter.time() - cc;
	if (lyCounter.ly() >= 143
			|| (lyCounter.ly() == 142 && next <= 4)
			|| (statReg & lcdstat_m0irqen)) {
		next += (153u - lyCounter.ly()) * lyCounter.lineTime();
	} else {
		next -= 4;
		if (next <= 0)
			next += lyCounter.lineTime();
	}

	return cc + next;
}

static unsigned long m0IrqTimeFromXpos166Time(unsigned long xpos166Time, bool cgb, bool ds) {
	return xpos166Time + cgb - ds;
}

static unsigned long hdmaTimeFromM0Time(unsigned long m0Time, bool ds) {
	return m0Time + 1 - ds;
}

static unsigned long nextHdmaTime(unsigned long lastM0Time,
		unsigned long nextM0Time, unsigned long cc, bool ds) {
	return cc < hdmaTimeFromM0Time(lastM0Time, ds)
	          ? hdmaTimeFromM0Time(lastM0Time, ds)
	          : hdmaTimeFromM0Time(nextM0Time, ds);
}

void LCD::setStatePtrs(SaveState &state) {
	state.ppu.bgpData.set(  bgpData_, sizeof  bgpData_);
	state.ppu.objpData.set(objpData_, sizeof objpData_);
	ppu_.setStatePtrs(state);
}

void LCD::saveState(SaveState &state) const {
	state.mem.hdmaTransfer = hdmaIsEnabled();
	state.ppu.nextM0Irq = eventTimes_(memevent_m0irq) - ppu_.now();
	state.ppu.pendingLcdstatIrq = eventTimes_(memevent_oneshot_statirq) != disabled_time;

	lycIrq_.saveState(state);
	m0Irq_.saveState(state);
	ppu_.saveState(state);
}

void LCD::loadState(SaveState const &state, unsigned char const *const oamram) {
	statReg_ = state.mem.ioamhram.get()[0x141];
	m2IrqStatReg_ = statReg_;
	m1IrqStatReg_ = statReg_;

	ppu_.loadState(state, oamram);
	lycIrq_.loadState(state);
	m0Irq_.loadState(state);

	if (ppu_.lcdc() & lcdc_en) {
		nextM0Time_.predictNextM0Time(ppu_);
		lycIrq_.reschedule(ppu_.lyCounter(), ppu_.now());

		eventTimes_.setm<memevent_oneshot_statirq>(
			  state.ppu.pendingLcdstatIrq
			? ppu_.now() + 1
			: static_cast<unsigned long>(disabled_time));
		eventTimes_.setm<memevent_oneshot_updatewy2>(
			  state.ppu.oldWy != state.mem.ioamhram.get()[0x14A]
			? ppu_.now() + 1
			: static_cast<unsigned long>(disabled_time));
		eventTimes_.set<event_ly>(ppu_.lyCounter().time());
		eventTimes_.setm<memevent_spritemap>(
			SpriteMapper::schedule(ppu_.lyCounter(), ppu_.now()));
		eventTimes_.setm<memevent_lycirq>(lycIrq_.time());
		eventTimes_.setm<memevent_m1irq>(
			ppu_.lyCounter().nextFrameCycle(144 * 456, ppu_.now()));
		eventTimes_.setm<memevent_m2irq>(
			mode2IrqSchedule(statReg_, ppu_.lyCounter(), ppu_.now()));
		eventTimes_.setm<memevent_m0irq>(statReg_ & lcdstat_m0irqen
			? ppu_.now() + state.ppu.nextM0Irq
			: static_cast<unsigned long>(disabled_time));
		eventTimes_.setm<memevent_hdma>(state.mem.hdmaTransfer
			? nextHdmaTime(ppu_.lastM0Time(), nextM0Time_.predictedNextM0Time(),
			               ppu_.now(), isDoubleSpeed())
			: static_cast<unsigned long>(disabled_time));
	} else for (int i = 0; i < num_memevents; ++i)
		eventTimes_.set(MemEvent(i), disabled_time);

	refreshPalettes();
}

void LCD::refreshPalettes() {
	if (ppu_.cgb()) {
		for (unsigned i = 0; i < 8 * 8; i += 2) {
			ppu_.bgPalette()[i >> 1] = gbcToRgb32( bgpData_[i] |  bgpData_[i + 1] << 8);
			ppu_.spPalette()[i >> 1] = gbcToRgb32(objpData_[i] | objpData_[i + 1] << 8);
		}
	} else {
		setDmgPalette(ppu_.bgPalette()    , dmgColorsRgb32_    ,  bgpData_[0]);
		setDmgPalette(ppu_.spPalette()    , dmgColorsRgb32_ + 4, objpData_[0]);
		setDmgPalette(ppu_.spPalette() + 4, dmgColorsRgb32_ + 8, objpData_[1]);
	}
}

namespace {

template<class Blend>
static void blitOsdElement(uint_least32_t *d, uint_least32_t const *s,
                           unsigned const width, unsigned h, std::ptrdiff_t const dpitch,
                           Blend blend)
{
	while (h--) {
		for (unsigned w = width; w--;) {
			if (*s != OsdElement::pixel_transparent)
				*d = blend(*s, *d);

			++d;
			++s;
		}

		d += dpitch - static_cast<std::ptrdiff_t>(width);
	}
}

template<unsigned weight>
struct Blend {
	enum { SW = weight - 1 };
	enum { LOWMASK = SW * 0x010101ul };

	uint_least32_t operator()(uint_least32_t s, uint_least32_t d) const {
		return (s * SW + d - (((s & LOWMASK) * SW + (d & LOWMASK)) & LOWMASK)) / weight;
	}
};

template<typename T>
static void clear(T *buf, unsigned long color, std::ptrdiff_t dpitch) {
	unsigned lines = 144;

	while (lines--) {
		std::fill_n(buf, 160, color);
		buf += dpitch;
	}
}

}

void LCD::updateScreen(bool const blanklcd, unsigned long const cycleCounter) {
	update(cycleCounter);

	if (blanklcd && ppu_.frameBuf().fb()) {
		unsigned long color = ppu_.cgb() ? gbcToRgb32(0xFFFF) : dmgColorsRgb32_[0];
		clear(ppu_.frameBuf().fb(), color, ppu_.frameBuf().pitch());
	}

	if (ppu_.frameBuf().fb() && osdElement_) {
		if (uint_least32_t const *const s = osdElement_->update()) {
			uint_least32_t *const d = ppu_.frameBuf().fb()
				+ std::ptrdiff_t(osdElement_->y()) * ppu_.frameBuf().pitch()
				+ osdElement_->x();

			switch (osdElement_->opacity()) {
			case OsdElement::seven_eighths:
				blitOsdElement(d, s, osdElement_->w(), osdElement_->h(),
				               ppu_.frameBuf().pitch(), Blend<8>());
				break;
			case OsdElement::three_fourths:
				blitOsdElement(d, s, osdElement_->w(), osdElement_->h(),
				               ppu_.frameBuf().pitch(), Blend<4>());
				break;
			}
		} else
			osdElement_.reset();
	}
}

void LCD::resetCc(unsigned long const oldCc, unsigned long const newCc) {
	update(oldCc);
	ppu_.resetCc(oldCc, newCc);

	if (ppu_.lcdc() & lcdc_en) {
		unsigned long const dec = oldCc - newCc;

		nextM0Time_.invalidatePredictedNextM0Time();
		lycIrq_.reschedule(ppu_.lyCounter(), newCc);

		for (int i = 0; i < num_memevents; ++i) {
			if (eventTimes_(MemEvent(i)) != disabled_time)
				eventTimes_.set(MemEvent(i), eventTimes_(MemEvent(i)) - dec);
		}

		eventTimes_.set<event_ly>(ppu_.lyCounter().time());
	}
}

void LCD::speedChange(unsigned long const cc) {
	update(cc);
	ppu_.speedChange(cc);

	if (ppu_.lcdc() & lcdc_en) {
		nextM0Time_.predictNextM0Time(ppu_);
		lycIrq_.reschedule(ppu_.lyCounter(), cc);

		eventTimes_.set<event_ly>(ppu_.lyCounter().time());
		eventTimes_.setm<memevent_spritemap>(SpriteMapper::schedule(ppu_.lyCounter(), cc));
		eventTimes_.setm<memevent_lycirq>(lycIrq_.time());
		eventTimes_.setm<memevent_m1irq>(ppu_.lyCounter().nextFrameCycle(144 * 456, cc));
		eventTimes_.setm<memevent_m2irq>(mode2IrqSchedule(statReg_, ppu_.lyCounter(), cc));

		if (eventTimes_(memevent_m0irq) != disabled_time
				&& eventTimes_(memevent_m0irq) - cc > 1) {
			eventTimes_.setm<memevent_m0irq>(m0IrqTimeFromXpos166Time(
				ppu_.predictedNextXposTime(166), ppu_.cgb(), isDoubleSpeed()));
		}

		if (hdmaIsEnabled() && eventTimes_(memevent_hdma) - cc > 1) {
			eventTimes_.setm<memevent_hdma>(nextHdmaTime(ppu_.lastM0Time(),
				nextM0Time_.predictedNextM0Time(), cc, isDoubleSpeed()));
		}
	}
}

static unsigned long m0TimeOfCurrentLine(
		unsigned long nextLyTime,
		unsigned long lastM0Time,
		unsigned long nextM0Time) {
	return nextM0Time < nextLyTime ? nextM0Time : lastM0Time;
}

unsigned long LCD::m0TimeOfCurrentLine(unsigned long const cc) {
	if (cc >= nextM0Time_.predictedNextM0Time()) {
		update(cc);
		nextM0Time_.predictNextM0Time(ppu_);
	}

	return gambatte::m0TimeOfCurrentLine(ppu_.lyCounter().time(), ppu_.lastM0Time(),
	                                     nextM0Time_.predictedNextM0Time());
}

static bool isHdmaPeriod(LyCounter const &lyCounter,
		unsigned long m0TimeOfCurrentLy, unsigned long cc) {
	int timeToNextLy = lyCounter.time() - cc;
	return lyCounter.ly() < 144 && timeToNextLy > 4
	    && cc >= hdmaTimeFromM0Time(m0TimeOfCurrentLy, lyCounter.isDoubleSpeed());
}

void LCD::enableHdma(unsigned long const cycleCounter) {
	if (cycleCounter >= nextM0Time_.predictedNextM0Time()) {
		update(cycleCounter);
		nextM0Time_.predictNextM0Time(ppu_);
	} else if (cycleCounter >= eventTimes_.nextEventTime())
		update(cycleCounter);

	unsigned long const m0TimeCurLy =
		gambatte::m0TimeOfCurrentLine(ppu_.lyCounter().time(),
		                              ppu_.lastM0Time(),
		                              nextM0Time_.predictedNextM0Time());
	if (isHdmaPeriod(ppu_.lyCounter(), m0TimeCurLy, cycleCounter))
		eventTimes_.flagHdmaReq();

	eventTimes_.setm<memevent_hdma>(nextHdmaTime(
		ppu_.lastM0Time(), nextM0Time_.predictedNextM0Time(),
		cycleCounter, isDoubleSpeed()));
}

void LCD::disableHdma(unsigned long const cycleCounter) {
	if (cycleCounter >= eventTimes_.nextEventTime())
		update(cycleCounter);

	eventTimes_.setm<memevent_hdma>(disabled_time);
}

bool LCD::vramAccessible(unsigned long const cc) {
	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	return !(ppu_.lcdc() & lcdc_en)
	    || ppu_.lyCounter().ly() >= 144
	    || ppu_.lyCounter().lineCycles(cc) < 80U
	    || cc + isDoubleSpeed() - ppu_.cgb() + 2 >= m0TimeOfCurrentLine(cc);
}

bool LCD::cgbpAccessible(unsigned long const cc) {
	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	return !(ppu_.lcdc() & lcdc_en)
	    || ppu_.lyCounter().ly() >= 144
	    || ppu_.lyCounter().lineCycles(cc) < 80U + isDoubleSpeed()
	    || cc >= m0TimeOfCurrentLine(cc) + 3 - isDoubleSpeed();
}

static void doCgbColorChange(unsigned char *pdata,
		unsigned long *palette, unsigned index, unsigned data) {
	pdata[index] = data;
	index >>= 1;
	palette[index] = gbcToRgb32(pdata[index * 2] | pdata[index * 2 + 1] << 8);
}

void LCD::doCgbBgColorChange(unsigned index, unsigned data, unsigned long cc) {
	if (cgbpAccessible(cc)) {
		update(cc);
		doCgbColorChange(bgpData_, ppu_.bgPalette(), index, data);
	}
}

void LCD::doCgbSpColorChange(unsigned index, unsigned data, unsigned long cc) {
	if (cgbpAccessible(cc)) {
		update(cc);
		doCgbColorChange(objpData_, ppu_.spPalette(), index, data);
	}
}

bool LCD::oamReadable(unsigned long const cc) {
	if (!(ppu_.lcdc() & lcdc_en) || ppu_.inactivePeriodAfterDisplayEnable(cc))
		return true;

	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	if (ppu_.lyCounter().lineCycles(cc) + 4 - isDoubleSpeed() * 3u >= 456)
		return ppu_.lyCounter().ly() >= 144-1 && ppu_.lyCounter().ly() != 153;

	return ppu_.lyCounter().ly() >= 144
	    || cc + isDoubleSpeed() - ppu_.cgb() + 2 >= m0TimeOfCurrentLine(cc);
}

bool LCD::oamWritable(unsigned long const cc) {
	if (!(ppu_.lcdc() & lcdc_en) || ppu_.inactivePeriodAfterDisplayEnable(cc))
		return true;

	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	if (ppu_.lyCounter().lineCycles(cc) + 3 + ppu_.cgb() - isDoubleSpeed() * 2u >= 456)
		return ppu_.lyCounter().ly() >= 144-1 && ppu_.lyCounter().ly() != 153;

	return ppu_.lyCounter().ly() >= 144
	    || cc + isDoubleSpeed() - ppu_.cgb() + 2 >= m0TimeOfCurrentLine(cc);
}

void LCD::mode3CyclesChange() {
	bool const ds = isDoubleSpeed();
	nextM0Time_.invalidatePredictedNextM0Time();

	if (eventTimes_(memevent_m0irq) != disabled_time
			&& eventTimes_(memevent_m0irq)
			   > m0IrqTimeFromXpos166Time(ppu_.now(), ppu_.cgb(), ds)) {
		unsigned long t = m0IrqTimeFromXpos166Time(ppu_.predictedNextXposTime(166),
		                                           ppu_.cgb(), ds);
		eventTimes_.setm<memevent_m0irq>(t);
	}

	if (eventTimes_(memevent_hdma) != disabled_time
			&& eventTimes_(memevent_hdma) > hdmaTimeFromM0Time(ppu_.lastM0Time(), ds)) {
		nextM0Time_.predictNextM0Time(ppu_);
		eventTimes_.setm<memevent_hdma>(
			hdmaTimeFromM0Time(nextM0Time_.predictedNextM0Time(), ds));
	}
}

void LCD::wxChange(unsigned newValue, unsigned long cycleCounter) {
	update(cycleCounter + isDoubleSpeed() + 1);
	ppu_.setWx(newValue);
	mode3CyclesChange();
}

void LCD::wyChange(unsigned const newValue, unsigned long const cc) {
	update(cc + 1);
	ppu_.setWy(newValue); 

	// mode3CyclesChange();
	// (should be safe to wait until after wy2 delay, because no mode3 events are
	// close to when wy1 is read.)

	// wy2 is a delayed version of wy. really just slowness of ly == wy comparison.
	if (ppu_.cgb() && (ppu_.lcdc() & lcdc_en)) {
		eventTimes_.setm<memevent_oneshot_updatewy2>(cc + 5);
	} else {
		update(cc + 2);
		ppu_.updateWy2();
		mode3CyclesChange();
	}
}

void LCD::scxChange(unsigned newScx, unsigned long cycleCounter) {
	update(cycleCounter + ppu_.cgb() + isDoubleSpeed());
	ppu_.setScx(newScx);
	mode3CyclesChange();
}

void LCD::scyChange(unsigned newValue, unsigned long cycleCounter) {
	update(cycleCounter + ppu_.cgb() + isDoubleSpeed());
	ppu_.setScy(newValue);
}

void LCD::oamChange(unsigned long cc) {
	if (ppu_.lcdc() & lcdc_en) {
		update(cc);
		ppu_.oamChange(cc);
		eventTimes_.setm<memevent_spritemap>(SpriteMapper::schedule(ppu_.lyCounter(), cc));
	}
}

void LCD::oamChange(unsigned char const *oamram, unsigned long cc) {
	update(cc);
	ppu_.oamChange(oamram, cc);

	if (ppu_.lcdc() & lcdc_en)
		eventTimes_.setm<memevent_spritemap>(SpriteMapper::schedule(ppu_.lyCounter(), cc));
}

void LCD::lcdcChange(unsigned const data, unsigned long const cc) {
	unsigned const oldLcdc = ppu_.lcdc();
	update(cc);

	if ((oldLcdc ^ data) & lcdc_en) {
		ppu_.setLcdc(data, cc);

		if (data & lcdc_en) {
			lycIrq_.lcdReset();
			m0Irq_.lcdReset(statReg_, lycIrq_.lycReg());

			if (lycIrq_.lycReg() == 0 && (statReg_ & lcdstat_lycirqen))
				eventTimes_.flagIrq(2);

			nextM0Time_.predictNextM0Time(ppu_);
			lycIrq_.reschedule(ppu_.lyCounter(), cc);

			eventTimes_.set<event_ly>(ppu_.lyCounter().time());
			eventTimes_.setm<memevent_spritemap>(
				SpriteMapper::schedule(ppu_.lyCounter(), cc));
			eventTimes_.setm<memevent_lycirq>(lycIrq_.time());
			eventTimes_.setm<memevent_m1irq>(
				ppu_.lyCounter().nextFrameCycle(144 * 456, cc));
			eventTimes_.setm<memevent_m2irq>(
				mode2IrqSchedule(statReg_, ppu_.lyCounter(), cc));
			if (statReg_ & lcdstat_m0irqen) {
				eventTimes_.setm<memevent_m0irq>(m0IrqTimeFromXpos166Time(
					ppu_.predictedNextXposTime(166), ppu_.cgb(), isDoubleSpeed()));
			}
			if (hdmaIsEnabled()) {
				eventTimes_.setm<memevent_hdma>(nextHdmaTime(ppu_.lastM0Time(),
					nextM0Time_.predictedNextM0Time(), cc, isDoubleSpeed()));
			}
		} else for (int i = 0; i < num_memevents; ++i)
			eventTimes_.set(MemEvent(i), disabled_time);
	} else if (data & lcdc_en) {
		if (ppu_.cgb()) {
			ppu_.setLcdc(  (oldLcdc & ~(lcdc_tdsel | lcdc_obj2x))
			             | (data    &  (lcdc_tdsel | lcdc_obj2x)), cc);

			if ((oldLcdc ^ data) & lcdc_obj2x) {
				unsigned long t = SpriteMapper::schedule(ppu_.lyCounter(), cc);
				eventTimes_.setm<memevent_spritemap>(t);
			}

			update(cc + isDoubleSpeed() + 1);
			ppu_.setLcdc(data, cc + isDoubleSpeed() + 1);

			if ((oldLcdc ^ data) & lcdc_we)
				mode3CyclesChange();
		} else {
			ppu_.setLcdc(data, cc);

			if ((oldLcdc ^ data) & lcdc_obj2x) {
				unsigned long t = SpriteMapper::schedule(ppu_.lyCounter(), cc);
				eventTimes_.setm<memevent_spritemap>(t);
			}

			if ((oldLcdc ^ data) & (lcdc_we | lcdc_objen))
				mode3CyclesChange();
		}
	} else
		ppu_.setLcdc(data, cc);
}

namespace {

struct LyCnt {
	unsigned ly; int timeToNextLy;
	LyCnt(unsigned ly, int timeToNextLy) : ly(ly), timeToNextLy(timeToNextLy) {}
};

static LyCnt const getLycCmpLy(LyCounter const &lyCounter, unsigned long cc) {
	unsigned ly = lyCounter.ly();
	int timeToNextLy = lyCounter.time() - cc;

	if (ly == 153) {
		if (timeToNextLy -  (448 << lyCounter.isDoubleSpeed()) > 0) {
			timeToNextLy -= (448 << lyCounter.isDoubleSpeed());
		} else {
			ly = 0;
			timeToNextLy += lyCounter.lineTime();
		}
	}

	return LyCnt(ly, timeToNextLy);
}

} // anon ns

inline bool LCD::statChangeTriggersStatIrqDmg(unsigned const old, unsigned long const cc) {
	LyCnt const lycCmp = getLycCmpLy(ppu_.lyCounter(), cc);

	if (ppu_.lyCounter().ly() < 144) {
		if (cc + 1 < m0TimeOfCurrentLine(cc))
			return lycCmp.ly == lycIrq_.lycReg() && !(old & lcdstat_lycirqen);

		return !(old & lcdstat_m0irqen)
		    && !(lycCmp.ly == lycIrq_.lycReg() && (old & lcdstat_lycirqen));
	}

	return !(old & lcdstat_m1irqen)
	    && !(lycCmp.ly == lycIrq_.lycReg() && (old & lcdstat_lycirqen));
}

static bool statChangeTriggersM2IrqCgb(unsigned const old,
		unsigned const data, unsigned const ly, int const timeToNextLy) {
	if ((old & lcdstat_m2irqen)
			|| (data & (lcdstat_m2irqen | lcdstat_m0irqen)) != lcdstat_m2irqen
			|| ly >= 144) {
		return false;
	}

	return  timeToNextLy == 456 * 2
	    || (timeToNextLy <= 4 && ly < 143);
}

inline bool LCD::statChangeTriggersM0LycOrM1StatIrqCgb(
		unsigned const old, unsigned const data, unsigned long const cc) {
	unsigned const ly = ppu_.lyCounter().ly();
	int const timeToNextLy = ppu_.lyCounter().time() - cc;
	LyCnt const lycCmp = getLycCmpLy(ppu_.lyCounter(), cc);
	bool const lycperiod = lycCmp.ly == lycIrq_.lycReg()
	                    && lycCmp.timeToNextLy > 4 - isDoubleSpeed() * 4;
	if (lycperiod && (old & lcdstat_lycirqen))
		return false;

	if (ly < 144) {
		if (cc + isDoubleSpeed() * 2 < m0TimeOfCurrentLine(cc) || timeToNextLy <= 4)
			return lycperiod && (data & lcdstat_lycirqen);

		if (old & lcdstat_m0irqen)
			return false;

		return (data & lcdstat_m0irqen)
		    || (lycperiod && (data & lcdstat_lycirqen));
	}

	if (old & lcdstat_m1irqen)
		return false;

	return ((data & lcdstat_m1irqen) && (ly < 153 || timeToNextLy > 4 - isDoubleSpeed() * 4))
	    || (lycperiod && (data & lcdstat_lycirqen));
}

inline bool LCD::statChangeTriggersStatIrqCgb(
		unsigned const old, unsigned const data, unsigned long const cc) {
	if (!(data & ~old & (  lcdstat_lycirqen
	                     | lcdstat_m2irqen
	                     | lcdstat_m1irqen
	                     | lcdstat_m0irqen))) {
		return false;
	}

	unsigned const ly = ppu_.lyCounter().ly();
	int const timeToNextLy = ppu_.lyCounter().time() - cc;
	return statChangeTriggersM0LycOrM1StatIrqCgb(old, data, cc)
	    || statChangeTriggersM2IrqCgb(old, data, ly, timeToNextLy);
}

inline bool LCD::statChangeTriggersStatIrq(unsigned old, unsigned data, unsigned long cc) {
	return ppu_.cgb()
	     ? statChangeTriggersStatIrqCgb(old, data, cc)
	     : statChangeTriggersStatIrqDmg(old, cc);
}

void LCD::lcdstatChange(unsigned const data, unsigned long const cc) {
	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	unsigned const old = statReg_;
	statReg_ = data;
	lycIrq_.statRegChange(data, ppu_.lyCounter(), cc);

	if (ppu_.lcdc() & lcdc_en) {
		if (statChangeTriggersStatIrq(old, data, cc))
			eventTimes_.flagIrq(2);

		if ((data & lcdstat_m0irqen) && eventTimes_(memevent_m0irq) == disabled_time) {
			update(cc);
			eventTimes_.setm<memevent_m0irq>(m0IrqTimeFromXpos166Time(
				ppu_.predictedNextXposTime(166), ppu_.cgb(), isDoubleSpeed()));
		}

		eventTimes_.setm<memevent_m2irq>(mode2IrqSchedule(data, ppu_.lyCounter(), cc));
		eventTimes_.setm<memevent_lycirq>(lycIrq_.time());
	}

	m2IrqStatReg_ = eventTimes_(memevent_m2irq) - cc > (ppu_.cgb() - isDoubleSpeed()) * 4U
	              ? data
	              : (m2IrqStatReg_ & lcdstat_m1irqen) | (statReg_ & ~lcdstat_m1irqen);
	m1IrqStatReg_ = eventTimes_(memevent_m1irq) - cc > (ppu_.cgb() - isDoubleSpeed()) * 4U
	              ? data
	              : (m1IrqStatReg_ & lcdstat_m0irqen) | (statReg_ & ~lcdstat_m0irqen);

	m0Irq_.statRegChange(data, eventTimes_(memevent_m0irq), cc, ppu_.cgb());
}

static unsigned incLy(unsigned ly) { return ly == 153 ? 0 : ly + 1; }

inline bool LCD::lycRegChangeStatTriggerBlockedByM0OrM1Irq(unsigned long const cc) {
	int const timeToNextLy = ppu_.lyCounter().time() - cc;
	if (ppu_.lyCounter().ly() < 144) {
		return (statReg_ & lcdstat_m0irqen)
		    && cc >= m0TimeOfCurrentLine(cc)
		    && timeToNextLy > 4 << ppu_.cgb();
	}

	return (statReg_ & lcdstat_m1irqen)
	    && !(ppu_.lyCounter().ly() == 153
	          && timeToNextLy <= 4
	          && ppu_.cgb() && !isDoubleSpeed());
}

bool LCD::lycRegChangeTriggersStatIrq(
		unsigned const old, unsigned const data, unsigned long const cc) {
	if (!(statReg_ & lcdstat_lycirqen) || data >= 154
			|| lycRegChangeStatTriggerBlockedByM0OrM1Irq(cc)) {
		return false;
	}

	LyCnt lycCmp = getLycCmpLy(ppu_.lyCounter(), cc);
	if (lycCmp.timeToNextLy <= 4 << ppu_.cgb()) {
		bool const ds = isDoubleSpeed();
		if (old == lycCmp.ly && !(lycCmp.timeToNextLy <= 4 && ppu_.cgb() && !ds))
			return false; // simultaneous ly/lyc inc. lyc flag never goes low -> no trigger.

		lycCmp.ly = incLy(lycCmp.ly);
	}

	return data == lycCmp.ly;
}

void LCD::lycRegChange(unsigned const data, unsigned long const cc) {
	unsigned const old = lycIrq_.lycReg();
	if (data == old)
		return;

	if (cc >= eventTimes_.nextEventTime())
		update(cc);

	m0Irq_.lycRegChange(data, eventTimes_(memevent_m0irq), cc, isDoubleSpeed(), ppu_.cgb());
	lycIrq_.lycRegChange(data, ppu_.lyCounter(), cc);

	if (ppu_.lcdc() & lcdc_en) {
		eventTimes_.setm<memevent_lycirq>(lycIrq_.time());

		if (lycRegChangeTriggersStatIrq(old, data, cc)) {
			if (ppu_.cgb() && !isDoubleSpeed()) {
				eventTimes_.setm<memevent_oneshot_statirq>(cc + 5);
			} else
				eventTimes_.flagIrq(2);
		}
	}
}

unsigned LCD::getStat(unsigned const lycReg, unsigned long const cc) {
	unsigned stat = 0;

	if (ppu_.lcdc() & lcdc_en) {
		if (cc >= eventTimes_.nextEventTime())
			update(cc);

		unsigned const ly = ppu_.lyCounter().ly();
		int const timeToNextLy = ppu_.lyCounter().time() - cc;
		if (ly > 143) {
			if (ly < 153 || timeToNextLy > 4 - isDoubleSpeed() * 4)
				stat = 1;
		} else {
			int const lineCycles = 456 - (timeToNextLy >> isDoubleSpeed());
			if (lineCycles < 80) {
				if (!ppu_.inactivePeriodAfterDisplayEnable(cc))
					stat = 2;
			} else if (cc + isDoubleSpeed() - ppu_.cgb() + 2 < m0TimeOfCurrentLine(cc))
				stat = 3;
		}

		LyCnt const lycCmp = getLycCmpLy(ppu_.lyCounter(), cc);
		if (lycReg == lycCmp.ly && lycCmp.timeToNextLy > 4 - isDoubleSpeed() * 4)
			stat |= lcdstat_lycflag;
	}

	return stat;
}

static bool isMode2IrqEventBlockedByM1Irq(unsigned ly, unsigned statreg) {
	return ly == 0 && (statreg & lcdstat_m1irqen);
}

static bool isMode2IrqEventBlockedByLycIrq(unsigned ly, unsigned statreg, unsigned lycreg) {
	return (statreg & lcdstat_lycirqen)
	    && (ly == 0 ? ly : ly - 1) == lycreg;
}

static bool isMode2IrqEventBlocked(unsigned ly, unsigned statreg, unsigned lycreg) {
	return isMode2IrqEventBlockedByM1Irq(ly, statreg)
	    || isMode2IrqEventBlockedByLycIrq(ly, statreg, lycreg);
}

inline void LCD::doMode2IrqEvent() {
	unsigned const ly = eventTimes_(event_ly) - eventTimes_(memevent_m2irq) < 8
	                  ? incLy(ppu_.lyCounter().ly())
	                  : ppu_.lyCounter().ly();
	if (!isMode2IrqEventBlocked(ly, m2IrqStatReg_, lycIrq_.lycReg()))
		eventTimes_.flagIrq(2);

	m2IrqStatReg_ = statReg_;

	if (!(statReg_ & lcdstat_m0irqen)) {
		unsigned long nextTime = eventTimes_(memevent_m2irq) + ppu_.lyCounter().lineTime();
		if (ly == 0) {
			nextTime -= 4;
		} else if (ly == 143)
			nextTime += ppu_.lyCounter().lineTime() * 10 + 4;

		eventTimes_.setm<memevent_m2irq>(nextTime);
	} else {
		eventTimes_.setm<memevent_m2irq>(eventTimes_(memevent_m2irq)
		                                 + (70224 << isDoubleSpeed()));
	}
}

inline void LCD::event() {
	switch (eventTimes_.nextEvent()) {
	case event_mem:
		switch (eventTimes_.nextMemEvent()) {
		case memevent_m1irq:
			eventTimes_.flagIrq((m1IrqStatReg_ & (lcdstat_m1irqen | lcdstat_m0irqen))
			                    == lcdstat_m1irqen
			                  ? 3
			                  : 1);
			m1IrqStatReg_ = statReg_;
			eventTimes_.setm<memevent_m1irq>(eventTimes_(memevent_m1irq)
			                                 + (70224 << isDoubleSpeed()));
			break;

		case memevent_lycirq: {
			unsigned char ifreg = 0;
			lycIrq_.doEvent(&ifreg, ppu_.lyCounter());
			eventTimes_.flagIrq(ifreg);
			eventTimes_.setm<memevent_lycirq>(lycIrq_.time());
			break;
		}

		case memevent_spritemap:
			eventTimes_.setm<memevent_spritemap>(
				ppu_.doSpriteMapEvent(eventTimes_(memevent_spritemap)));
			mode3CyclesChange();
			break;

		case memevent_hdma:
			eventTimes_.flagHdmaReq();
			nextM0Time_.predictNextM0Time(ppu_);
			eventTimes_.setm<memevent_hdma>(hdmaTimeFromM0Time(
				nextM0Time_.predictedNextM0Time(), isDoubleSpeed()));
			break;

		case memevent_m2irq:
			doMode2IrqEvent();
			break;

		case memevent_m0irq:
			{
				unsigned char ifreg = 0;
				m0Irq_.doEvent(&ifreg, ppu_.lyCounter().ly(), statReg_,
				               lycIrq_.lycReg());
				eventTimes_.flagIrq(ifreg);
			}

			eventTimes_.setm<memevent_m0irq>(statReg_ & lcdstat_m0irqen
				? m0IrqTimeFromXpos166Time(ppu_.predictedNextXposTime(166),
				                           ppu_.cgb(), isDoubleSpeed())
				: static_cast<unsigned long>(disabled_time));
			break;

		case memevent_oneshot_statirq:
			eventTimes_.flagIrq(2);
			eventTimes_.setm<memevent_oneshot_statirq>(disabled_time);
			break;

		case memevent_oneshot_updatewy2:
			ppu_.updateWy2();
			mode3CyclesChange();
			eventTimes_.setm<memevent_oneshot_updatewy2>(disabled_time);
			break;
		}

		break;

	case event_ly:
		ppu_.doLyCountEvent();
		eventTimes_.set<event_ly>(ppu_.lyCounter().time());
		break;
	}
}

void LCD::update(unsigned long const cycleCounter) {
	if (!(ppu_.lcdc() & lcdc_en))
		return;

	while (cycleCounter >= eventTimes_.nextEventTime()) {
		ppu_.update(eventTimes_.nextEventTime());
		event();
	}

	ppu_.update(cycleCounter);
}

void LCD::setVideoBuffer(uint_least32_t *videoBuf, std::ptrdiff_t pitch) {
	ppu_.setFrameBuf(videoBuf, pitch);
}

void LCD::setDmgPaletteColor(unsigned palNum, unsigned colorNum, unsigned long rgb32) {
	if (palNum > 2 || colorNum > 3)
		return;

	dmgColorsRgb32_[palNum * 4 + colorNum] = rgb32;
	refreshPalettes();
}

}
