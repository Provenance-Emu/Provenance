#ifndef __MDFN_NES_FDS_H
#define __MDFN_NES_FDS_H

namespace MDFN_IEN_NES
{
void FDSSoundReset(void);
bool FDS_SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx);
}

#endif
