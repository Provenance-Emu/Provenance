#pragma once
#include "drkPvr.h"
#include "hw/holly/holly_intc.h"
#include "hw/sh4/sh4_if.h"
#include "oslib/oslib.h"
#include "ta_structs.h"

struct TA_context;

void ta_init();
void ta_reset();
void ta_term();


void ta_vtx_ListCont();
void ta_vtx_ListInit();
void ta_vtx_SoftReset();

void DYNACALL ta_vtx_data32(void* data);
void ta_vtx_data(u32* data, u32 size);

bool ta_parse_vdrc(TA_context* ctx);


#define STRIPS_AS_PPARAMS 1
#define TRIG_SORT 1


#if TRIG_SORT 
#undef STRIPS_AS_PPARAMS
#define STRIPS_AS_PPARAMS 1
#endif