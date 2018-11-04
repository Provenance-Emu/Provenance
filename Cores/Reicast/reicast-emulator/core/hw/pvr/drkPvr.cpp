// drkPvr.cpp : Defines the entry point for the DLL application.
//

/*
	Plugin structure
	Interface
	SPG
	TA
	Renderer
*/

#include "drkPvr.h"

#include "ta.h"
#include "spg.h"
#include "pvr_regs.h"
#include "pvr_mem.h"
#include "Renderer_if.h"


void libPvr_LockedBlockWrite (vram_block* block,u32 addr)
{
	rend_text_invl(block);
}


void libPvr_Reset(bool Manual)
{
	Regs_Reset(Manual);
	spg_Reset(Manual);
	//rend_reset(); //*TODO* wtf ?
}

s32 libPvr_Init()
{
	if (!spg_Init())
	{
		//failed
		return rv_error;
	}
	if (!rend_init())
	{
		//failed
		return rv_error;
	}

	return rv_ok;
}

//called when exiting from sh4 thread , from the new thread context (for any thread specific de init) :P
void libPvr_Term()
{
	rend_term();
	spg_Term();
}