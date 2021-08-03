#include "../snes/snes.hpp"

#define DSP_CPP
namespace SNES {

DSP dsp;

#include "SPC_DSP.cpp"

void DSP::power()
{
  spc_dsp.init(smp.apuram);
  spc_dsp.reset();
  clock = 0;
}

void DSP::reset()
{
  spc_dsp.soft_reset();
  clock = 0;
}

static void from_dsp_to_state (uint8 **buf, void *var, size_t size)
{
  memcpy(*buf, var, size);
  *buf += size;
}

static void to_dsp_from_state (uint8 **buf, void *var, size_t size)
{
	memcpy(var, *buf, size);
	*buf += size;
}

void DSP::save_state (uint8 **ptr)
{
	spc_dsp.copy_state(ptr, from_dsp_to_state);
}

void DSP::load_state (uint8 **ptr)
{
	spc_dsp.copy_state(ptr, to_dsp_from_state);
}

DSP::DSP()
{
	clock = 0;
}

}
