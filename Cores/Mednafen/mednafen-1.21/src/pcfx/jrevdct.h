#ifndef __MDFN_PCFX_JREVDCT_H
#define __MDFN_PCFX_JREVDCT_H

namespace MDFN_IEN_PCFX
{

typedef int32* DCTBLOCK;     
typedef int32 DCTELEM;

void j_rev_dct(DCTBLOCK data);

}

#endif
