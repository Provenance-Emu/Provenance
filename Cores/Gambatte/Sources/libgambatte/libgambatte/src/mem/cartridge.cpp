//
//   Copyright (C) 2007-2010 by sinamas <sinamas at users.sourceforge.net>
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

#include "cartridge.h"
#include "file/file.h"
#include "../savestate.h"
#include "pakinfo_internal.h"
#include <cstring>
#include <fstream>

namespace gambatte {

namespace {

static unsigned toMulti64Rombank(unsigned rombank) {
	return (rombank >> 1 & 0x30) | (rombank & 0xF);
}

class DefaultMbc : public Mbc {
public:
	virtual bool isAddressWithinAreaRombankCanBeMappedTo(unsigned addr, unsigned bank) const {
		return (addr< 0x4000) == (bank == 0);
	}
};

class Mbc0 : public DefaultMbc {
public:
	explicit Mbc0(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, enableRam_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		if (p < 0x2000) {
			enableRam_ = (data & 0xF) == 0xA;
			memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.enableRam = enableRam_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		enableRam_ = ss.enableRam;
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
	}

private:
	MemPtrs &memptrs_;
	bool enableRam_;
};

static inline unsigned rambanks(MemPtrs const &memptrs) {
	return std::size_t(memptrs.rambankdataend() - memptrs.rambankdata()) / 0x2000;
}

static inline unsigned rombanks(MemPtrs const &memptrs) {
	return std::size_t(memptrs.romdataend()     - memptrs.romdata()    ) / 0x4000;
}

class Mbc1 : public DefaultMbc {
public:
	explicit Mbc1(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, rombank_(1)
	, rambank_(0)
	, enableRam_(false)
	, rambankMode_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p >> 13 & 3) {
		case 0:
			enableRam_ = (data & 0xF) == 0xA;
			setRambank();
			break;
		case 1:
			rombank_ = rambankMode_ ? data & 0x1F : (rombank_ & 0x60) | (data & 0x1F);
			setRombank();
			break;
		case 2:
			if (rambankMode_) {
				rambank_ = data & 3;
				setRambank();
			} else {
				rombank_ = (data << 5 & 0x60) | (rombank_ & 0x1F);
				setRombank();
			}

			break;
		case 3:
			// Pretty sure this should take effect immediately, but I have a policy not to change old behavior
			// unless I have something (eg. a verified test or a game) that justifies it.
			rambankMode_ = data & 1;
			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.rambank = rambank_;
		ss.enableRam = enableRam_;
		ss.rambankMode = rambankMode_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		rambank_ = ss.rambank;
		enableRam_ = ss.enableRam;
		rambankMode_ = ss.rambankMode;
		setRambank();
		setRombank();
	}

private:
	MemPtrs &memptrs_;
	unsigned char rombank_;
	unsigned char rambank_;
	bool enableRam_;
	bool rambankMode_;

	static unsigned adjustedRombank(unsigned bank) { return bank & 0x1F ? bank : bank | 1; }

	void setRambank() const {
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0,
		                    rambank_ & (rambanks(memptrs_) - 1));
	}

	void setRombank() const { memptrs_.setRombank(adjustedRombank(rombank_) & (rombanks(memptrs_) - 1)); }
};

class Mbc1Multi64 : public Mbc {
public:
	explicit Mbc1Multi64(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, rombank_(1)
	, enableRam_(false)
	, rombank0Mode_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p >> 13 & 3) {
		case 0:
			enableRam_ = (data & 0xF) == 0xA;
			memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
			break;
		case 1:
			rombank_ = (rombank_   & 0x60) | (data    & 0x1F);
			memptrs_.setRombank(rombank0Mode_
				? adjustedRombank(toMulti64Rombank(rombank_))
				: adjustedRombank(rombank_) & (rombanks(memptrs_) - 1));
			break;
		case 2:
			rombank_ = (data << 5 & 0x60) | (rombank_ & 0x1F);
			setRombank();
			break;
		case 3:
			rombank0Mode_ = data & 1;
			setRombank();
			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.enableRam = enableRam_;
		ss.rambankMode = rombank0Mode_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		enableRam_ = ss.enableRam;
		rombank0Mode_ = ss.rambankMode;
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
		setRombank();
	}

	virtual bool isAddressWithinAreaRombankCanBeMappedTo(unsigned addr, unsigned bank) const {
		return (addr < 0x4000) == ((bank & 0xF) == 0);
	}

private:
	MemPtrs &memptrs_;
	unsigned char rombank_;
	bool enableRam_;
	bool rombank0Mode_;

	static unsigned adjustedRombank(unsigned bank) { return bank & 0x1F ? bank : bank | 1; }

	void setRombank() const {
		if (rombank0Mode_) {
			unsigned const rb = toMulti64Rombank(rombank_);
			memptrs_.setRombank0(rb & 0x30);
			memptrs_.setRombank(adjustedRombank(rb));
		} else {
			memptrs_.setRombank0(0);
			memptrs_.setRombank(adjustedRombank(rombank_) & (rombanks(memptrs_) - 1));
		}
	}
};

class Mbc2 : public DefaultMbc {
public:
	explicit Mbc2(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, rombank_(1)
	, enableRam_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p & 0x6100) {
		case 0x0000:
			enableRam_ = (data & 0xF) == 0xA;
			memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
			break;
		case 0x2100:
			rombank_ = data & 0xF;
			memptrs_.setRombank(rombank_ & (rombanks(memptrs_) - 1));
			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.enableRam = enableRam_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		enableRam_ = ss.enableRam;
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0, 0);
		memptrs_.setRombank(rombank_ & (rombanks(memptrs_) - 1));
	}

private:
	MemPtrs &memptrs_;
	unsigned char rombank_;
	bool enableRam_;
};

class Mbc3 : public DefaultMbc {
public:
	Mbc3(MemPtrs &memptrs, Rtc *const rtc)
	: memptrs_(memptrs)
	, rtc_(rtc)
	, rombank_(1)
	, rambank_(0)
	, enableRam_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p >> 13 & 3) {
		case 0:
			enableRam_ = (data & 0xF) == 0xA;
			setRambank();
			break;
		case 1:
			rombank_ = data & 0x7F;
			setRombank();
			break;
		case 2:
			rambank_ = data;
			setRambank();
			break;
		case 3:
			if (rtc_)
				rtc_->latch(data);

			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.rambank = rambank_;
		ss.enableRam = enableRam_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		rambank_ = ss.rambank;
		enableRam_ = ss.enableRam;
		setRambank();
		setRombank();
	}

private:
	MemPtrs &memptrs_;
	Rtc *const rtc_;
	unsigned char rombank_;
	unsigned char rambank_;
	bool enableRam_;

	void setRambank() const {
		unsigned flags = enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0;

		if (rtc_) {
			rtc_->set(enableRam_, rambank_);

			if (rtc_->activeData())
				flags |= MemPtrs::rtc_en;
		}

		memptrs_.setRambank(flags, rambank_ & (rambanks(memptrs_) - 1));
	}

	void setRombank() const {
		memptrs_.setRombank(std::max(rombank_ & (rombanks(memptrs_) - 1), 1u));
	}
};

class HuC1 : public DefaultMbc {
public:
	explicit HuC1(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, rombank_(1)
	, rambank_(0)
	, enableRam_(false)
	, rambankMode_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p >> 13 & 3) {
		case 0:
			enableRam_ = (data & 0xF) == 0xA;
			setRambank();
			break;
		case 1:
			rombank_ = data & 0x3F;
			setRombank();
			break;
		case 2:
			rambank_ = data & 3;
			rambankMode_ ? setRambank() : setRombank();
			break;
		case 3:
			rambankMode_ = data & 1;
			setRambank();
			setRombank();
			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.rambank = rambank_;
		ss.enableRam = enableRam_;
		ss.rambankMode = rambankMode_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		rambank_ = ss.rambank;
		enableRam_ = ss.enableRam;
		rambankMode_ = ss.rambankMode;
		setRambank();
		setRombank();
	}

private:
	MemPtrs &memptrs_;
	unsigned char rombank_;
	unsigned char rambank_;
	bool enableRam_;
	bool rambankMode_;

	void setRambank() const {
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : MemPtrs::read_en,
		                    rambankMode_ ? rambank_ & (rambanks(memptrs_) - 1) : 0);
	}

	void setRombank() const {
		memptrs_.setRombank((rambankMode_ ? rombank_ : rambank_ << 6 | rombank_)
		                  & (rombanks(memptrs_) - 1));
	}
};

class Mbc5 : public DefaultMbc {
public:
	explicit Mbc5(MemPtrs &memptrs)
	: memptrs_(memptrs)
	, rombank_(1)
	, rambank_(0)
	, enableRam_(false)
	{
	}

	virtual void romWrite(unsigned const p, unsigned const data) {
		switch (p >> 13 & 3) {
		case 0:
			enableRam_ = (data & 0xF) == 0xA;
			setRambank();
			break;
		case 1:
			rombank_ = p < 0x3000
			         ? (rombank_  & 0x100) |  data
			         : (data << 8 & 0x100) | (rombank_ & 0xFF);
			setRombank();
			break;
		case 2:
			rambank_ = data & 0xF;
			setRambank();
			break;
		case 3:
			break;
		}
	}

	virtual void saveState(SaveState::Mem &ss) const {
		ss.rombank = rombank_;
		ss.rambank = rambank_;
		ss.enableRam = enableRam_;
	}

	virtual void loadState(SaveState::Mem const &ss) {
		rombank_ = ss.rombank;
		rambank_ = ss.rambank;
		enableRam_ = ss.enableRam;
		setRambank();
		setRombank();
	}

private:
	MemPtrs &memptrs_;
	unsigned short rombank_;
	unsigned char rambank_;
	bool enableRam_;

	static unsigned adjustedRombank(unsigned bank) { return bank ? bank : 1; }

	void setRambank() const {
		memptrs_.setRambank(enableRam_ ? MemPtrs::read_en | MemPtrs::write_en : 0,
		                    rambank_ & (rambanks(memptrs_) - 1));
	}

	void setRombank() const { memptrs_.setRombank(adjustedRombank(rombank_) & (rombanks(memptrs_) - 1)); }
};

static bool hasRtc(unsigned headerByte0x147) {
	switch (headerByte0x147) {
	case 0x0F:
	case 0x10: return true;
	default: return false;
	}
}

}

void Cartridge::setStatePtrs(SaveState &state) {
	state.mem.vram.set(memptrs_.vramdata(), memptrs_.vramdataend() - memptrs_.vramdata());
	state.mem.sram.set(memptrs_.rambankdata(), memptrs_.rambankdataend() - memptrs_.rambankdata());
	state.mem.wram.set(memptrs_.wramdata(0), memptrs_.wramdataend() - memptrs_.wramdata(0));
}

void Cartridge::saveState(SaveState &state) const {
	mbc_->saveState(state.mem);
	rtc_.saveState(state);
}

void Cartridge::loadState(SaveState const &state) {
	rtc_.loadState(state);
	mbc_->loadState(state.mem);
}

static std::string const stripExtension(std::string const &str) {
	std::string::size_type const lastDot = str.find_last_of('.');
	std::string::size_type const lastSlash = str.find_last_of('/');

	if (lastDot != std::string::npos && (lastSlash == std::string::npos || lastSlash < lastDot))
		return str.substr(0, lastDot);

	return str;
}

static std::string const stripDir(std::string const &str) {
	std::string::size_type const lastSlash = str.find_last_of('/');
	if (lastSlash != std::string::npos)
		return str.substr(lastSlash + 1);

	return str;
}

std::string const Cartridge::saveBasePath() const {
	return saveDir_.empty()
	     ? defaultSaveBasePath_
	     : saveDir_ + stripDir(defaultSaveBasePath_);
}

void Cartridge::setSaveDir(std::string const &dir) {
	saveDir_ = dir;
	if (!saveDir_.empty() && saveDir_[saveDir_.length() - 1] != '/')
		saveDir_ += '/';
}

static void enforce8bit(unsigned char *data, std::size_t size) {
	if (static_cast<unsigned char>(0x100))
		while (size--)
			*data++ &= 0xFF;
}

static unsigned pow2ceil(unsigned n) {
	--n;
	n |= n >> 1;
	n |= n >> 2;
	n |= n >> 4;
	n |= n >> 8;
	++n;

	return n;
}

static bool presumedMulti64Mbc1(unsigned char const header[], unsigned rombanks) {
	return header[0x147] == 1 && header[0x149] == 0 && rombanks == 64;
}

LoadRes Cartridge::loadROM(std::string const &romfile,
                           bool const forceDmg,
                           bool const multicartCompat)
{
	scoped_ptr<File> const rom(newFileInstance(romfile));
	if (rom->fail())
		return LOADRES_IO_ERROR;

	enum Cartridgetype { type_plain,
	                     type_mbc1,
	                     type_mbc2,
	                     type_mbc3,
	                     type_mbc5,
	                     type_huc1 };
	Cartridgetype type = type_plain;
	unsigned rambanks = 1;
	unsigned rombanks = 2;
	bool cgb = false;

	{
		unsigned char header[0x150];
		rom->read(reinterpret_cast<char *>(header), sizeof header);

		switch (header[0x0147]) {
		case 0x00: type = type_plain; break;
		case 0x01:
		case 0x02:
		case 0x03: type = type_mbc1; break;
		case 0x05:
		case 0x06: type = type_mbc2; break;
		case 0x08:
		case 0x09: type = type_plain; break;
		case 0x0B:
		case 0x0C:
		case 0x0D: return LOADRES_UNSUPPORTED_MBC_MMM01;
		case 0x0F:
		case 0x10:
		case 0x11:
		case 0x12:
		case 0x13: type = type_mbc3; break;
		case 0x15:
		case 0x16:
		case 0x17: return LOADRES_UNSUPPORTED_MBC_MBC4;
		case 0x19:
		case 0x1A:
		case 0x1B:
		case 0x1C:
		case 0x1D:
		case 0x1E: type = type_mbc5; break;
		case 0x20: return LOADRES_UNSUPPORTED_MBC_MBC6;
		case 0x22: return LOADRES_UNSUPPORTED_MBC_MBC7;
		case 0xFC: return LOADRES_UNSUPPORTED_MBC_POCKET_CAMERA;
		case 0xFD: return LOADRES_UNSUPPORTED_MBC_TAMA5;
		case 0xFE: return LOADRES_UNSUPPORTED_MBC_HUC3;
		case 0xFF: type = type_huc1; break;
		default:   return LOADRES_BAD_FILE_OR_UNKNOWN_MBC;
		}

		/*switch (header[0x0148]) {
		case 0x00: rombanks = 2; break;
		case 0x01: rombanks = 4; break;
		case 0x02: rombanks = 8; break;
		case 0x03: rombanks = 16; break;
		case 0x04: rombanks = 32; break;
		case 0x05: rombanks = 64; break;
		case 0x06: rombanks = 128; break;
		case 0x07: rombanks = 256; break;
		case 0x08: rombanks = 512; break;
		case 0x52: rombanks = 72; break;
		case 0x53: rombanks = 80; break;
		case 0x54: rombanks = 96; break;
		default: return -1;
		}*/

		//rambanks = numRambanksFromH14x(header[0x147], header[0x149]);
        
        switch (header[0x0149]) {
            case 0x00: /*std::puts("No RAM");*/ rambanks = type == type_mbc2; break;
            case 0x01: /*std::puts("2kB RAM");*/ /*rambankrom=1; break;*/
            case 0x02: /*std::puts("8kB RAM");*/
                rambanks = 1;
                break;
            case 0x03: /*std::puts("32kB RAM");*/
                rambanks = 4;
                break;
            case 0x04: /*std::puts("128kB RAM");*/
                rambanks = 16;
                break;
            case 0x05: /*std::puts("undocumented kB RAM");*/
                rambanks = 16;
                break;
            default: /*std::puts("Wrong data-format, corrupt or unsupported ROM loaded.");*/
                rambanks = 16;
                break;
        }
        
		cgb = header[0x0143] >> 7 & (1 ^ forceDmg);
	}

	std::size_t const filesize = rom->size();
	rombanks = std::max(pow2ceil(filesize / 0x4000), 2u);

	defaultSaveBasePath_.clear();
	ggUndoList_.clear();
	mbc_.reset();
	memptrs_.reset(rombanks, rambanks, cgb ? 8 : 2);
	rtc_.set(false, 0);

	rom->rewind();
	rom->read(reinterpret_cast<char*>(memptrs_.romdata()), filesize / 0x4000 * 0x4000ul);
	std::memset(memptrs_.romdata() + filesize / 0x4000 * 0x4000ul,
	            0xFF,
	            (rombanks - filesize / 0x4000) * 0x4000ul);
	enforce8bit(memptrs_.romdata(), rombanks * 0x4000ul);

	if (rom->fail())
		return LOADRES_IO_ERROR;

	defaultSaveBasePath_ = stripExtension(romfile);

	switch (type) {
	case type_plain: mbc_.reset(new Mbc0(memptrs_)); break;
	case type_mbc1:
		if (multicartCompat && presumedMulti64Mbc1(memptrs_.romdata(), rombanks)) {
			mbc_.reset(new Mbc1Multi64(memptrs_));
		} else
			mbc_.reset(new Mbc1(memptrs_));

		break;
	case type_mbc2: mbc_.reset(new Mbc2(memptrs_)); break;
	case type_mbc3:
		mbc_.reset(new Mbc3(memptrs_, hasRtc(memptrs_.romdata()[0x147]) ? &rtc_ : 0));
		break;
	case type_mbc5: mbc_.reset(new Mbc5(memptrs_)); break;
	case type_huc1: mbc_.reset(new HuC1(memptrs_)); break;
	}

	return LOADRES_OK;
}

static bool hasBattery(unsigned char headerByte0x147) {
	switch (headerByte0x147) {
	case 0x03:
	case 0x06:
	case 0x09:
	case 0x0F:
	case 0x10:
	case 0x13:
	case 0x1B:
	case 0x1E:
	case 0xFF: return true;
	default: return false;
	}
}

void Cartridge::loadSavedata() {
	std::string const &sbp = saveBasePath();

	if (hasBattery(memptrs_.romdata()[0x147])) {
		std::ifstream file((sbp + ".sav").c_str(), std::ios::binary | std::ios::in);

		if (file.is_open()) {
			file.read(reinterpret_cast<char*>(memptrs_.rambankdata()),
			          memptrs_.rambankdataend() - memptrs_.rambankdata());
			enforce8bit(memptrs_.rambankdata(), memptrs_.rambankdataend() - memptrs_.rambankdata());
		}
	}

	if (hasRtc(memptrs_.romdata()[0x147])) {
		std::ifstream file((sbp + ".rtc").c_str(), std::ios::binary | std::ios::in);
		if (file) {
			unsigned long basetime =    file.get() & 0xFF;
			basetime = basetime << 8 | (file.get() & 0xFF);
			basetime = basetime << 8 | (file.get() & 0xFF);
			basetime = basetime << 8 | (file.get() & 0xFF);
			rtc_.setBaseTime(basetime);
		}
	}
}

void Cartridge::saveSavedata() {
	std::string const &sbp = saveBasePath();

	if (hasBattery(memptrs_.romdata()[0x147])) {
		std::ofstream file((sbp + ".sav").c_str(), std::ios::binary | std::ios::out);
		file.write(reinterpret_cast<char const *>(memptrs_.rambankdata()),
		           memptrs_.rambankdataend() - memptrs_.rambankdata());
	}

	if (hasRtc(memptrs_.romdata()[0x147])) {
		std::ofstream file((sbp + ".rtc").c_str(), std::ios::binary | std::ios::out);
		unsigned long const basetime = rtc_.baseTime();
		file.put(basetime >> 24 & 0xFF);
		file.put(basetime >> 16 & 0xFF);
		file.put(basetime >>  8 & 0xFF);
		file.put(basetime       & 0xFF);
	}
}

static int asHex(char c) {
	return c >= 'A' ? c - 'A' + 0xA : c - '0';
}

void Cartridge::applyGameGenie(std::string const &code) {
	if (6 < code.length()) {
		unsigned const val = (asHex(code[0]) << 4 | asHex(code[1])) & 0xFF;
		unsigned const addr = (    asHex(code[2])        <<  8
		                        |  asHex(code[4])        <<  4
		                        |  asHex(code[5])
		                        | (asHex(code[6]) ^ 0xF) << 12) & 0x7FFF;
		unsigned cmp = 0xFFFF;
		if (10 < code.length()) {
			cmp = (asHex(code[8]) << 4 | asHex(code[10])) ^ 0xFF;
			cmp = ((cmp >> 2 | cmp << 6) ^ 0x45) & 0xFF;
		}

		for (unsigned bank = 0; bank < std::size_t(memptrs_.romdataend() - memptrs_.romdata()) / 0x4000; ++bank) {
			if (mbc_->isAddressWithinAreaRombankCanBeMappedTo(addr, bank)
					&& (cmp > 0xFF || memptrs_.romdata()[bank * 0x4000ul + (addr & 0x3FFF)] == cmp)) {
				ggUndoList_.push_back(AddrData(bank * 0x4000ul + (addr & 0x3FFF),
				                      memptrs_.romdata()[bank * 0x4000ul + (addr & 0x3FFF)]));
				memptrs_.romdata()[bank * 0x4000ul + (addr & 0x3FFF)] = val;
			}
		}
	}
}

void Cartridge::setGameGenie(std::string const &codes) {
	if (loaded()) {
		for (std::vector<AddrData>::reverse_iterator it =
				ggUndoList_.rbegin(), end = ggUndoList_.rend(); it != end; ++it) {
			if (memptrs_.romdata() + it->addr < memptrs_.romdataend())
				memptrs_.romdata()[it->addr] = it->data;
		}

		ggUndoList_.clear();

		std::string code;
		for (std::size_t pos = 0; pos < codes.length(); pos += code.length() + 1) {
			code = codes.substr(pos, codes.find('+', pos) - pos);
			applyGameGenie(code);
		}
	}
}

PakInfo const Cartridge::pakInfo(bool const multipakCompat) const {
	if (loaded()) {
		unsigned const rombs = rombanks(memptrs_);
		return PakInfo(multipakCompat && presumedMulti64Mbc1(memptrs_.romdata(), rombs),
		               rombs,
		               memptrs_.romdata());
	}

	return PakInfo();
}

}
