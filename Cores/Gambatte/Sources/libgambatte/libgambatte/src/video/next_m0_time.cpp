#include "next_m0_time.h"
#include "ppu.h"

void gambatte::NextM0Time::predictNextM0Time(PPU const &ppu) {
	predictedNextM0Time_ = ppu.predictedNextXposTime(167);
}
