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

#include "memory.h"
#include "inputgetter.h"
#include "savestate.h"
#include "sound.h"
#include "video.h"
#include <cstring>

namespace gambatte {

Memory::Memory(Interrupter const &interrupter)
: getInput_(0)
, divLastUpdate_(0)
, lastOamDmaUpdate_(disabled_time)
, lcd_(ioamhram_, 0, VideoInterruptRequester(intreq_))
, interrupter_(interrupter)
, dmaSource_(0)
, dmaDestination_(0)
, oamDmaPos_(0xFE)
, serialCnt_(0)
, blanklcd_(false)
{
	intreq_.setEventTime<intevent_blit>(144 * 456ul);
	intreq_.setEventTime<intevent_end>(0);
}

void Memory::setStatePtrs(SaveState &state) {
	state.mem.ioamhram.set(ioamhram_, sizeof ioamhram_);

	cart_.setStatePtrs(state);
	lcd_.setStatePtrs(state);
	psg_.setStatePtrs(state);
}

unsigned long Memory::saveState(SaveState &state, unsigned long cc) {
	cc = resetCounters(cc);
	nontrivial_ff_read(0x05, cc);
	nontrivial_ff_read(0x0F, cc);
	nontrivial_ff_read(0x26, cc);

	state.mem.divLastUpdate = divLastUpdate_;
	state.mem.nextSerialtime = intreq_.eventTime(intevent_serial);
	state.mem.unhaltTime = intreq_.eventTime(intevent_unhalt);
	state.mem.lastOamDmaUpdate = lastOamDmaUpdate_;
	state.mem.dmaSource = dmaSource_;
	state.mem.dmaDestination = dmaDestination_;
	state.mem.oamDmaPos = oamDmaPos_;

	intreq_.saveState(state);
	cart_.saveState(state);
	tima_.saveState(state);
	lcd_.saveState(state);
	psg_.saveState(state);

	return cc;
}

static int serialCntFrom(unsigned long cyclesUntilDone, bool cgbFast) {
	return cgbFast ? (cyclesUntilDone + 0xF) >> 4 : (cyclesUntilDone + 0x1FF) >> 9;
}

void Memory::loadState(SaveState const &state) {
	psg_.loadState(state);
	lcd_.loadState(state, state.mem.oamDmaPos < 0xA0 ? cart_.rdisabledRam() : ioamhram_);
	tima_.loadState(state, TimaInterruptRequester(intreq_));
	cart_.loadState(state);
	intreq_.loadState(state);

	divLastUpdate_ = state.mem.divLastUpdate;
	intreq_.setEventTime<intevent_serial>(state.mem.nextSerialtime > state.cpu.cycleCounter
		? state.mem.nextSerialtime
		: state.cpu.cycleCounter);
	intreq_.setEventTime<intevent_unhalt>(state.mem.unhaltTime);
	lastOamDmaUpdate_ = state.mem.lastOamDmaUpdate;
	dmaSource_ = state.mem.dmaSource;
	dmaDestination_ = state.mem.dmaDestination;
	oamDmaPos_ = state.mem.oamDmaPos;
	serialCnt_ = intreq_.eventTime(intevent_serial) != disabled_time
	           ? serialCntFrom(intreq_.eventTime(intevent_serial) - state.cpu.cycleCounter,
	                           ioamhram_[0x102] & isCgb() * 2)
	           : 8;

	cart_.setVrambank(ioamhram_[0x14F] & isCgb());
	cart_.setOamDmaSrc(oam_dma_src_off);
	cart_.setWrambank(isCgb() && (ioamhram_[0x170] & 0x07) ? ioamhram_[0x170] & 0x07 : 1);

	if (lastOamDmaUpdate_ != disabled_time) {
		oamDmaInitSetup();

		unsigned oamEventPos = oamDmaPos_ < 0xA0 ? 0xA0 : 0x100;
		intreq_.setEventTime<intevent_oam>(
			lastOamDmaUpdate_ + (oamEventPos - oamDmaPos_) * 4);
	}

	intreq_.setEventTime<intevent_blit>(ioamhram_[0x140] & lcdc_en
	                                 ? lcd_.nextMode1IrqTime()
	                                 : state.cpu.cycleCounter);
	blanklcd_ = false;

	if (!isCgb())
		std::memset(cart_.vramdata() + 0x2000, 0, 0x2000);
}

void Memory::setEndtime(unsigned long cc, unsigned long inc) {
	if (intreq_.eventTime(intevent_blit) <= cc) {
		intreq_.setEventTime<intevent_blit>(intreq_.eventTime(intevent_blit)
		                                   + (70224 << isDoubleSpeed()));
	}

	intreq_.setEventTime<intevent_end>(cc + (inc << isDoubleSpeed()));
}

void Memory::updateSerial(unsigned long const cc) {
	if (intreq_.eventTime(intevent_serial) != disabled_time) {
		if (intreq_.eventTime(intevent_serial) <= cc) {
			ioamhram_[0x101] = (((ioamhram_[0x101] + 1) << serialCnt_) - 1) & 0xFF;
			ioamhram_[0x102] &= 0x7F;
			intreq_.setEventTime<intevent_serial>(disabled_time);
			intreq_.flagIrq(8);
		} else {
			int const targetCnt = serialCntFrom(intreq_.eventTime(intevent_serial) - cc,
			                                    ioamhram_[0x102] & isCgb() * 2);
			ioamhram_[0x101] = (((ioamhram_[0x101] + 1) << (serialCnt_ - targetCnt)) - 1) & 0xFF;
			serialCnt_ = targetCnt;
		}
	}
}

void Memory::updateTimaIrq(unsigned long cc) {
	while (intreq_.eventTime(intevent_tima) <= cc)
		tima_.doIrqEvent(TimaInterruptRequester(intreq_));
}

void Memory::updateIrqs(unsigned long cc) {
	updateSerial(cc);
	updateTimaIrq(cc);
	lcd_.update(cc);
}

unsigned long Memory::event(unsigned long cc) {
	if (lastOamDmaUpdate_ != disabled_time)
		updateOamDma(cc);

	switch (intreq_.minEventId()) {
	case intevent_unhalt:
		intreq_.unhalt();
		intreq_.setEventTime<intevent_unhalt>(disabled_time);
		break;
	case intevent_end:
		intreq_.setEventTime<intevent_end>(disabled_time - 1);

		while (cc >= intreq_.minEventTime()
				&& intreq_.eventTime(intevent_end) != disabled_time) {
			cc = event(cc);
		}

		intreq_.setEventTime<intevent_end>(disabled_time);

		break;
	case intevent_blit:
		{
			bool const lcden = ioamhram_[0x140] & lcdc_en;
			unsigned long blitTime = intreq_.eventTime(intevent_blit);

			if (lcden | blanklcd_) {
				lcd_.updateScreen(blanklcd_, cc);
				intreq_.setEventTime<intevent_blit>(disabled_time);
				intreq_.setEventTime<intevent_end>(disabled_time);

				while (cc >= intreq_.minEventTime())
					cc = event(cc);
			} else
				blitTime += 70224 << isDoubleSpeed();

			blanklcd_ = lcden ^ 1;
			intreq_.setEventTime<intevent_blit>(blitTime);
		}
		break;
	case intevent_serial:
		updateSerial(cc);
		break;
	case intevent_oam:
		intreq_.setEventTime<intevent_oam>(lastOamDmaUpdate_ == disabled_time
			? static_cast<unsigned long>(disabled_time)
			: intreq_.eventTime(intevent_oam) + 0xA0 * 4);
		break;
	case intevent_dma:
		{
			bool const doubleSpeed = isDoubleSpeed();
			unsigned dmaSrc = dmaSource_;
			unsigned dmaDest = dmaDestination_;
			unsigned dmaLength = ((ioamhram_[0x155] & 0x7F) + 0x1) * 0x10;
			unsigned length = hdmaReqFlagged(intreq_) ? 0x10 : dmaLength;

			ackDmaReq(intreq_);

			if ((static_cast<unsigned long>(dmaDest) + length) & 0x10000) {
				length = 0x10000 - dmaDest;
				ioamhram_[0x155] |= 0x80;
			}

			dmaLength -= length;

			if (!(ioamhram_[0x140] & lcdc_en))
				dmaLength = 0;

			{
				unsigned long lOamDmaUpdate = lastOamDmaUpdate_;
				lastOamDmaUpdate_ = disabled_time;

				while (length--) {
					unsigned const src = dmaSrc++ & 0xFFFF;
					unsigned const data = (src & 0xE000) == 0x8000 || src > 0xFDFF
					                    ? 0xFF
					                    : read(src, cc);

					cc += 2 << doubleSpeed;

					if (cc - 3 > lOamDmaUpdate) {
						oamDmaPos_ = (oamDmaPos_ + 1) & 0xFF;
						lOamDmaUpdate += 4;

						if (oamDmaPos_ < 0xA0) {
							if (oamDmaPos_ == 0)
								startOamDma(lOamDmaUpdate - 1);

							ioamhram_[src & 0xFF] = data;
						} else if (oamDmaPos_ == 0xA0) {
							endOamDma(lOamDmaUpdate - 1);
							lOamDmaUpdate = disabled_time;
						}
					}

					nontrivial_write(0x8000 | (dmaDest++ & 0x1FFF), data, cc);
				}

				lastOamDmaUpdate_ = lOamDmaUpdate;
			}

			cc += 4;

			dmaSource_ = dmaSrc;
			dmaDestination_ = dmaDest;
			ioamhram_[0x155] = ((dmaLength / 0x10 - 0x1) & 0xFF) | (ioamhram_[0x155] & 0x80);

			if ((ioamhram_[0x155] & 0x80) && lcd_.hdmaIsEnabled()) {
				if (lastOamDmaUpdate_ != disabled_time)
					updateOamDma(cc);

				lcd_.disableHdma(cc);
			}
		}

		break;
	case intevent_tima:
		tima_.doIrqEvent(TimaInterruptRequester(intreq_));
		break;
	case intevent_video:
		lcd_.update(cc);
		break;
	case intevent_interrupts:
		if (halted()) {
			if (isCgb())
				cc += 4;

			intreq_.unhalt();
			intreq_.setEventTime<intevent_unhalt>(disabled_time);
		}

		if (ime()) {
			unsigned const pendingIrqs = intreq_.pendingIrqs();
			unsigned const n = pendingIrqs & -pendingIrqs;
			unsigned address;
			if (n <= 4) {
				static unsigned char const lut[] = { 0x40, 0x48, 0x48, 0x50 };
				address = lut[n-1];
			} else
				address = 0x50 + n;

			intreq_.ackIrq(n);
			cc = interrupter_.interrupt(address, cc, *this);
		}

		break;
	}

	return cc;
}

unsigned long Memory::stop(unsigned long cc) {
	cc += 4 + 4 * isDoubleSpeed();

	if (ioamhram_[0x14D] & isCgb()) {
		psg_.generateSamples(cc, isDoubleSpeed());
		lcd_.speedChange(cc);
		ioamhram_[0x14D] ^= 0x81;
		intreq_.setEventTime<intevent_blit>(ioamhram_[0x140] & lcdc_en
			? lcd_.nextMode1IrqTime()
			: cc + (70224 << isDoubleSpeed()));

		if (intreq_.eventTime(intevent_end) > cc) {
			intreq_.setEventTime<intevent_end>(cc
				+ (  isDoubleSpeed()
				   ? (intreq_.eventTime(intevent_end) - cc) << 1
				   : (intreq_.eventTime(intevent_end) - cc) >> 1));
		}
	}

	intreq_.halt();
	intreq_.setEventTime<intevent_unhalt>(cc + 0x20000 + isDoubleSpeed() * 8);
	return cc;
}

static void decCycles(unsigned long &counter, unsigned long dec) {
	if (counter != disabled_time)
		counter -= dec;
}

void Memory::decEventCycles(IntEventId eventId, unsigned long dec) {
	if (intreq_.eventTime(eventId) != disabled_time)
		intreq_.setEventTime(eventId, intreq_.eventTime(eventId) - dec);
}

unsigned long Memory::resetCounters(unsigned long cc) {
	if (lastOamDmaUpdate_ != disabled_time)
		updateOamDma(cc);

	updateIrqs(cc);

	{
		unsigned long divinc = (cc - divLastUpdate_) >> 8;
		ioamhram_[0x104] = (ioamhram_[0x104] + divinc) & 0xFF;
		divLastUpdate_ += divinc << 8;
	}

	unsigned long const dec = cc < 0x10000
	                        ? 0
	                        : (cc & ~0x7FFFul) - 0x8000;
	decCycles(divLastUpdate_, dec);
	decCycles(lastOamDmaUpdate_, dec);
	decEventCycles(intevent_serial, dec);
	decEventCycles(intevent_oam, dec);
	decEventCycles(intevent_blit, dec);
	decEventCycles(intevent_end, dec);
	decEventCycles(intevent_unhalt, dec);

	unsigned long const oldCC = cc;
	cc -= dec;
	intreq_.resetCc(oldCC, cc);
	tima_.resetCc(oldCC, cc, TimaInterruptRequester(intreq_));
	lcd_.resetCc(oldCC, cc);
	psg_.resetCounter(cc, oldCC, isDoubleSpeed());
	return cc;
}

void Memory::updateInput() {
	unsigned state = 0xF;

	if ((ioamhram_[0x100] & 0x30) != 0x30 && getInput_) {
		unsigned input = (*getInput_)();
		unsigned dpad_state = ~input >> 4;
		unsigned button_state = ~input;
		if (!(ioamhram_[0x100] & 0x10))
			state &= dpad_state;
		if (!(ioamhram_[0x100] & 0x20))
			state &= button_state;
	}

	if (state != 0xF && (ioamhram_[0x100] & 0xF) == 0xF)
		intreq_.flagIrq(0x10);

	ioamhram_[0x100] = (ioamhram_[0x100] & -0x10u) | state;
}

void Memory::updateOamDma(unsigned long const cc) {
	unsigned char const *const oamDmaSrc = oamDmaSrcPtr();
	unsigned cycles = (cc - lastOamDmaUpdate_) >> 2;

	while (cycles--) {
		oamDmaPos_ = (oamDmaPos_ + 1) & 0xFF;
		lastOamDmaUpdate_ += 4;

		if (oamDmaPos_ < 0xA0) {
			if (oamDmaPos_ == 0)
				startOamDma(lastOamDmaUpdate_ - 1);

			ioamhram_[oamDmaPos_] = oamDmaSrc ? oamDmaSrc[oamDmaPos_] : cart_.rtcRead();
		} else if (oamDmaPos_ == 0xA0) {
			endOamDma(lastOamDmaUpdate_ - 1);
			lastOamDmaUpdate_ = disabled_time;
			break;
		}
	}
}

void Memory::oamDmaInitSetup() {
	if (ioamhram_[0x146] < 0xA0) {
		cart_.setOamDmaSrc(ioamhram_[0x146] < 0x80 ? oam_dma_src_rom : oam_dma_src_vram);
	} else if (ioamhram_[0x146] < 0xFE - isCgb() * 0x1E) {
		cart_.setOamDmaSrc(ioamhram_[0x146] < 0xC0 ? oam_dma_src_sram : oam_dma_src_wram);
	} else
		cart_.setOamDmaSrc(oam_dma_src_invalid);
}

static unsigned char const * oamDmaSrcZero() {
	static unsigned char zeroMem[0xA0];
	return zeroMem;
}

unsigned char const * Memory::oamDmaSrcPtr() const {
	switch (cart_.oamDmaSrc()) {
	case oam_dma_src_rom:
		return cart_.romdata(ioamhram_[0x146] >> 6) + (ioamhram_[0x146] << 8);
	case oam_dma_src_sram:
		return cart_.rsrambankptr() ? cart_.rsrambankptr() + (ioamhram_[0x146] << 8) : 0;
	case oam_dma_src_vram:
		return cart_.vrambankptr() + (ioamhram_[0x146] << 8);
	case oam_dma_src_wram:
		return cart_.wramdata(ioamhram_[0x146] >> 4 & 1) + (ioamhram_[0x146] << 8 & 0xFFF);
	case oam_dma_src_invalid:
	case oam_dma_src_off:
		break;
	}

	return ioamhram_[0x146] == 0xFF && !isCgb() ? oamDmaSrcZero() : cart_.rdisabledRam();
}

void Memory::startOamDma(unsigned long cc) {
	lcd_.oamChange(cart_.rdisabledRam(), cc);
}

void Memory::endOamDma(unsigned long cc) {
	oamDmaPos_ = 0xFE;
	cart_.setOamDmaSrc(oam_dma_src_off);
	lcd_.oamChange(ioamhram_, cc);
}

unsigned Memory::nontrivial_ff_read(unsigned const p, unsigned long const cc) {
	if (lastOamDmaUpdate_ != disabled_time)
		updateOamDma(cc);

	switch (p) {
	case 0x00:
		updateInput();
		break;
	case 0x01:
	case 0x02:
		updateSerial(cc);
		break;
	case 0x04:
		{
			unsigned long divcycles = (cc - divLastUpdate_) >> 8;
			ioamhram_[0x104] = (ioamhram_[0x104] + divcycles) & 0xFF;
			divLastUpdate_ += divcycles << 8;
		}

		break;
	case 0x05:
		ioamhram_[0x105] = tima_.tima(cc);
		break;
	case 0x0F:
		updateIrqs(cc);
		ioamhram_[0x10F] = intreq_.ifreg();
		break;
	case 0x26:
		if (ioamhram_[0x126] & 0x80) {
			psg_.generateSamples(cc, isDoubleSpeed());
			ioamhram_[0x126] = 0xF0 | psg_.getStatus();
		} else
			ioamhram_[0x126] = 0x70;

		break;
	case 0x30:
	case 0x31:
	case 0x32:
	case 0x33:
	case 0x34:
	case 0x35:
	case 0x36:
	case 0x37:
	case 0x38:
	case 0x39:
	case 0x3A:
	case 0x3B:
	case 0x3C:
	case 0x3D:
	case 0x3E:
	case 0x3F:
		psg_.generateSamples(cc, isDoubleSpeed());
		return psg_.waveRamRead(p & 0xF);
	case 0x41:
		return ioamhram_[0x141] | lcd_.getStat(ioamhram_[0x145], cc);
	case 0x44:
		return lcd_.getLyReg(cc);
	case 0x69:
		return lcd_.cgbBgColorRead(ioamhram_[0x168] & 0x3F, cc);
	case 0x6B:
		return lcd_.cgbSpColorRead(ioamhram_[0x16A] & 0x3F, cc);
	default:
		break;
	}

	return ioamhram_[p + 0x100];
}

static bool isInOamDmaConflictArea(OamDmaSrc const oamDmaSrc, unsigned const p, bool const cgb) {
	struct Area { unsigned short areaUpper, exceptAreaLower, exceptAreaWidth, pad; };

	static Area const cgbAreas[] = {
		{ 0xC000, 0x8000, 0x2000, 0 },
		{ 0xC000, 0x8000, 0x2000, 0 },
		{ 0xA000, 0x0000, 0x8000, 0 },
		{ 0xFE00, 0x0000, 0xC000, 0 },
		{ 0xC000, 0x8000, 0x2000, 0 },
		{ 0x0000, 0x0000, 0x0000, 0 }
	};

	static Area const dmgAreas[] = {
		{ 0xFE00, 0x8000, 0x2000, 0 },
		{ 0xFE00, 0x8000, 0x2000, 0 },
		{ 0xA000, 0x0000, 0x8000, 0 },
		{ 0xFE00, 0x8000, 0x2000, 0 },
		{ 0xFE00, 0x8000, 0x2000, 0 },
		{ 0x0000, 0x0000, 0x0000, 0 }
	};

	Area const *a = cgb ? cgbAreas : dmgAreas;
	return p < a[oamDmaSrc].areaUpper
	    && p - a[oamDmaSrc].exceptAreaLower >= a[oamDmaSrc].exceptAreaWidth;
}

unsigned Memory::nontrivial_read(unsigned const p, unsigned long const cc) {
	if (p < 0xFF80) {
		if (lastOamDmaUpdate_ != disabled_time) {
			updateOamDma(cc);

			if (isInOamDmaConflictArea(cart_.oamDmaSrc(), p, isCgb()) && oamDmaPos_ < 0xA0)
				return ioamhram_[oamDmaPos_];
		}

		if (p < 0xC000) {
			if (p < 0x8000)
				return cart_.romdata(p >> 14)[p];

			if (p < 0xA000) {
				if (!lcd_.vramAccessible(cc))
					return 0xFF;

				return cart_.vrambankptr()[p];
			}

			if (cart_.rsrambankptr())
				return cart_.rsrambankptr()[p];

			return cart_.rtcRead();
		}

		if (p < 0xFE00)
			return cart_.wramdata(p >> 12 & 1)[p & 0xFFF];

		long const ffp = long(p) - 0xFF00;
		if (ffp >= 0)
			return nontrivial_ff_read(ffp, cc);

		if (!lcd_.oamReadable(cc) || oamDmaPos_ < 0xA0)
			return 0xFF;
	}

	return ioamhram_[p - 0xFE00];
}

void Memory::nontrivial_ff_write(unsigned const p, unsigned data, unsigned long const cc) {
	if (lastOamDmaUpdate_ != disabled_time)
		updateOamDma(cc);

	switch (p & 0xFF) {
	case 0x00:
		if ((data ^ ioamhram_[0x100]) & 0x30) {
			ioamhram_[0x100] = (ioamhram_[0x100] & ~0x30u) | (data & 0x30);
			updateInput();
		}

		return;
	case 0x01:
		updateSerial(cc);
		break;
	case 0x02:
		updateSerial(cc);
		serialCnt_ = 8;

		if ((data & 0x81) == 0x81) {
			intreq_.setEventTime<intevent_serial>(data & isCgb() * 2
				? (cc & ~0x07ul) + 0x010 * 8
				: (cc & ~0xFFul) + 0x200 * 8);
		} else
			intreq_.setEventTime<intevent_serial>(disabled_time);

		data |= 0x7E - isCgb() * 2;
		break;
	case 0x04:
		ioamhram_[0x104] = 0;
		divLastUpdate_ = cc;
		return;
	case 0x05:
		tima_.setTima(data, cc, TimaInterruptRequester(intreq_));
		break;
	case 0x06:
		tima_.setTma(data, cc, TimaInterruptRequester(intreq_));
		break;
	case 0x07:
		data |= 0xF8;
		tima_.setTac(data, cc, TimaInterruptRequester(intreq_));
		break;
	case 0x0F:
		updateIrqs(cc);
		intreq_.setIfreg(0xE0 | data);
		return;
	case 0x10:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr10(data);
		data |= 0x80;
		break;
	case 0x11:
		if (!psg_.isEnabled()) {
			if (isCgb())
				return;

			data &= 0x3F;
		}

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr11(data);
		data |= 0x3F;
		break;
	case 0x12:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr12(data);
		break;
	case 0x13:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr13(data);
		return;
	case 0x14:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr14(data);
		data |= 0xBF;
		break;
	case 0x16:
		if (!psg_.isEnabled()) {
			if (isCgb())
				return;

			data &= 0x3F;
		}

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr21(data);
		data |= 0x3F;
		break;
	case 0x17:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr22(data);
		break;
	case 0x18:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr23(data);
		return;
	case 0x19:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr24(data);
		data |= 0xBF;
		break;
	case 0x1A:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr30(data);
		data |= 0x7F;
		break;
	case 0x1B:
		if (!psg_.isEnabled() && isCgb())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr31(data);
		return;
	case 0x1C:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr32(data);
		data |= 0x9F;
		break;
	case 0x1D:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr33(data);
		return;
	case 0x1E:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr34(data);
		data |= 0xBF;
		break;
	case 0x20:
		if (!psg_.isEnabled() && isCgb())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr41(data);
		return;
	case 0x21:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr42(data);
		break;
	case 0x22:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr43(data);
		break;
	case 0x23:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setNr44(data);
		data |= 0xBF;
		break;
	case 0x24:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.setSoVolume(data);
		break;
	case 0x25:
		if (!psg_.isEnabled())
			return;

		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.mapSo(data);
		break;
	case 0x26:
		if ((ioamhram_[0x126] ^ data) & 0x80) {
			psg_.generateSamples(cc, isDoubleSpeed());

			if (!(data & 0x80)) {
				for (unsigned i = 0x10; i < 0x26; ++i)
					ff_write(i, 0, cc);

				psg_.setEnabled(false);
			} else {
				psg_.reset();
				psg_.setEnabled(true);
			}
		}

		data = (data & 0x80) | (ioamhram_[0x126] & 0x7F);
		break;
	case 0x30:
	case 0x31:
	case 0x32:
	case 0x33:
	case 0x34:
	case 0x35:
	case 0x36:
	case 0x37:
	case 0x38:
	case 0x39:
	case 0x3A:
	case 0x3B:
	case 0x3C:
	case 0x3D:
	case 0x3E:
	case 0x3F:
		psg_.generateSamples(cc, isDoubleSpeed());
		psg_.waveRamWrite(p & 0xF, data);
		break;
	case 0x40:
		if (ioamhram_[0x140] != data) {
			if ((ioamhram_[0x140] ^ data) & lcdc_en) {
				unsigned const lyc = lcd_.getStat(ioamhram_[0x145], cc)
				                     & lcdstat_lycflag;
				bool const hdmaEnabled = lcd_.hdmaIsEnabled();

				lcd_.lcdcChange(data, cc);
				ioamhram_[0x144] = 0;
				ioamhram_[0x141] &= 0xF8;

				if (data & lcdc_en) {
					intreq_.setEventTime<intevent_blit>(blanklcd_
						? lcd_.nextMode1IrqTime()
						: lcd_.nextMode1IrqTime()
						  + (70224 << isDoubleSpeed()));
				} else {
					ioamhram_[0x141] |= lyc;
					intreq_.setEventTime<intevent_blit>(
						cc + (456 * 4 << isDoubleSpeed()));

					if (hdmaEnabled)
						flagHdmaReq(intreq_);
				}
			} else
				lcd_.lcdcChange(data, cc);

			ioamhram_[0x140] = data;
		}

		return;
	case 0x41:
		lcd_.lcdstatChange(data, cc);
		data = (ioamhram_[0x141] & 0x87) | (data & 0x78);
		break;
	case 0x42:
		lcd_.scyChange(data, cc);
		break;
	case 0x43:
		lcd_.scxChange(data, cc);
		break;
	case 0x45:
		lcd_.lycRegChange(data, cc);
		break;
	case 0x46:
		if (lastOamDmaUpdate_ != disabled_time)
			endOamDma(cc);

		lastOamDmaUpdate_ = cc;
		intreq_.setEventTime<intevent_oam>(cc + 8);
		ioamhram_[0x146] = data;
		oamDmaInitSetup();
		return;
	case 0x47:
		if (!isCgb())
			lcd_.dmgBgPaletteChange(data, cc);

		break;
	case 0x48:
		if (!isCgb())
			lcd_.dmgSpPalette1Change(data, cc);

		break;
	case 0x49:
		if (!isCgb())
			lcd_.dmgSpPalette2Change(data, cc);

		break;
	case 0x4A:
		lcd_.wyChange(data, cc);
		break;
	case 0x4B:
		lcd_.wxChange(data, cc);
		break;

	case 0x4D:
		if (isCgb())
			ioamhram_[0x14D] = (ioamhram_[0x14D] & ~1u) | (data & 1);

		return;
	case 0x4F:
		if (isCgb()) {
			cart_.setVrambank(data & 1);
			ioamhram_[0x14F] = 0xFE | data;
		}

		return;
	case 0x51:
		dmaSource_ = data << 8 | (dmaSource_ & 0xFF);
		return;
	case 0x52:
		dmaSource_ = (dmaSource_ & 0xFF00) | (data & 0xF0);
		return;
	case 0x53:
		dmaDestination_ = data << 8 | (dmaDestination_ & 0xFF);
		return;
	case 0x54:
		dmaDestination_ = (dmaDestination_ & 0xFF00) | (data & 0xF0);
		return;
	case 0x55:
		if (isCgb()) {
			ioamhram_[0x155] = data & 0x7F;

			if (lcd_.hdmaIsEnabled()) {
				if (!(data & 0x80)) {
					ioamhram_[0x155] |= 0x80;
					lcd_.disableHdma(cc);
				}
			} else {
				if (data & 0x80) {
					if (ioamhram_[0x140] & lcdc_en) {
						lcd_.enableHdma(cc);
					} else
						flagHdmaReq(intreq_);
				} else
					flagGdmaReq(intreq_);
			}
		}

		return;
	case 0x56:
		if (isCgb())
			ioamhram_[0x156] = data | 0x3E;

		return;
	case 0x68:
		if (isCgb())
			ioamhram_[0x168] = data | 0x40;

		return;
	case 0x69:
		if (isCgb()) {
			unsigned index = ioamhram_[0x168] & 0x3F;
			lcd_.cgbBgColorChange(index, data, cc);
			ioamhram_[0x168] = (ioamhram_[0x168] & ~0x3F)
			                 | ((index + (ioamhram_[0x168] >> 7)) & 0x3F);
		}

		return;
	case 0x6A:
		if (isCgb())
			ioamhram_[0x16A] = data | 0x40;

		return;
	case 0x6B:
		if (isCgb()) {
			unsigned index = ioamhram_[0x16A] & 0x3F;
			lcd_.cgbSpColorChange(index, data, cc);
			ioamhram_[0x16A] = (ioamhram_[0x16A] & ~0x3F)
			                 | ((index + (ioamhram_[0x16A] >> 7)) & 0x3F);
		}

		return;
	case 0x6C:
		if (isCgb())
			ioamhram_[0x16C] = data | 0xFE;

		return;
	case 0x70:
		if (isCgb()) {
			cart_.setWrambank(data & 0x07 ? data & 0x07 : 1);
			ioamhram_[0x170] = data | 0xF8;
		}

		return;
	case 0x72:
	case 0x73:
	case 0x74:
		if (isCgb())
			break;

		return;
	case 0x75:
		if (isCgb())
			ioamhram_[0x175] = data | 0x8F;

		return;
	case 0xFF:
		intreq_.setIereg(data);
		break;
	default:
		return;
	}

	ioamhram_[p + 0x100] = data;
}

void Memory::nontrivial_write(unsigned const p, unsigned const data, unsigned long const cc) {
	if (lastOamDmaUpdate_ != disabled_time) {
		updateOamDma(cc);

		if (isInOamDmaConflictArea(cart_.oamDmaSrc(), p, isCgb()) && oamDmaPos_ < 0xA0) {
			ioamhram_[oamDmaPos_] = data;
			return;
		}
	}

	if (p < 0xFE00) {
		if (p < 0xA000) {
			if (p < 0x8000) {
				cart_.mbcWrite(p, data);
			} else if (lcd_.vramAccessible(cc)) {
				lcd_.vramChange(cc);
				cart_.vrambankptr()[p] = data;
			}
		} else if (p < 0xC000) {
			if (cart_.wsrambankptr())
				cart_.wsrambankptr()[p] = data;
			else
				cart_.rtcWrite(data);
		} else
			cart_.wramdata(p >> 12 & 1)[p & 0xFFF] = data;
	} else if (p - 0xFF80u >= 0x7Fu) {
		long const ffp = long(p) - 0xFF00;
		if (ffp < 0) {
			if (lcd_.oamWritable(cc) && oamDmaPos_ >= 0xA0 && (p < 0xFEA0 || isCgb())) {
				lcd_.oamChange(cc);
				ioamhram_[p - 0xFE00] = data;
			}
		} else
			nontrivial_ff_write(ffp, data, cc);
	} else
		ioamhram_[p - 0xFE00] = data;
}

LoadRes Memory::loadROM(std::string const &romfile, bool const forceDmg, bool const multicartCompat) {
	if (LoadRes const fail = cart_.loadROM(romfile, forceDmg, multicartCompat))
		return fail;

	psg_.init(cart_.isCgb());
	lcd_.reset(ioamhram_, cart_.vramdata(), cart_.isCgb());
	interrupter_.setGameShark(std::string());

	return LOADRES_OK;
}

std::size_t Memory::fillSoundBuffer(unsigned long cc) {
	psg_.generateSamples(cc, isDoubleSpeed());
	return psg_.fillBuffer();
}

}
