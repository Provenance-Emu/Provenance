#ifndef __MDFN_MD_CD_H
#define __MDFN_MD_CD_H

namespace MDFN_IEN_MD
{

extern M68K Sub68K;

void MDCD_Run(int32 md_master_cycles);
void MDCD_PCM_Run(int32 cycles);
void MDCD_Reset(bool poweron);
void MDCD_Load(std::vector<CDIF *> *CDInterfaces, md_game_info *);
bool MDCD_TestMagic(std::vector<CDIF *> *CDInterfaces);
void MDCD_Close(void);

}

#endif
