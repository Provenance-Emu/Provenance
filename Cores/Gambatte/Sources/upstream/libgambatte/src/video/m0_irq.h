#ifndef M0_IRQ_H
#define M0_IRQ_H

#include "lcddef.h"
#include "../savestate.h"

namespace gambatte {

class M0Irq {
public:
	M0Irq()
	: statReg_(0)
	, lycReg_(0)
	{
	}

	void lcdReset(unsigned statReg, unsigned lycReg) {
		statReg_ = statReg;
		 lycReg_ =  lycReg;
	}

	void statRegChange(unsigned statReg,
	                   unsigned long nextM0IrqTime, unsigned long cc, bool cgb) {
		if (nextM0IrqTime - cc > cgb * 2U)
			statReg_ = statReg;
	}

	void lycRegChange(unsigned lycReg,
	                  unsigned long nextM0IrqTime, unsigned long cc,
	                  bool ds, bool cgb) {
		if (nextM0IrqTime - cc > cgb * 5 + 1U - ds)
			lycReg_ = lycReg;
	}

	void doEvent(unsigned char *ifreg, unsigned ly, unsigned statReg, unsigned lycReg) {
		if (((statReg_ | statReg) & lcdstat_m0irqen)
				&& (!(statReg_ & lcdstat_lycirqen) || ly != lycReg_)) {
			*ifreg |= 2;
		}

		statReg_ = statReg;
		 lycReg_ =  lycReg;
	}

	void saveState(SaveState &state) const {
		state.ppu.m0lyc = lycReg_;
	}

	void loadState(SaveState const &state) {
		 lycReg_ = state.ppu.m0lyc;
		statReg_ = state.mem.ioamhram.get()[0x141];
	}

	unsigned statReg() const { return statReg_; }

private:
	unsigned char statReg_;
	unsigned char lycReg_;
};

}

#endif
