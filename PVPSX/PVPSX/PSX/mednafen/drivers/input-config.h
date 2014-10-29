#ifndef __MDFN_DRIVERS_INPUT_CONFIG_H
#define __MDFN_DRIVERS_INPUT_CONFIG_H

int DTestButton(std::vector<ButtConfig> &bc, const char *KeyState, const uint32* MouseData, bool analog = false);
int DTestButton(ButtConfig &bc, const char *KeyState, const uint32 *MouseData, bool analog = false);

int DTestButtonCombo(std::vector<ButtConfig> &bc, const char *KeyState, const uint32 *MouseData, bool AND_Mode = false);
int DTestButtonCombo(ButtConfig &bc, const char *KeyState, const uint32 *MouseData, bool AND_Mode = false);

int32 DTestMouseAxis(ButtConfig &bc, const char* KeyState, const uint32* MouseData, const bool axis_hint);

int DTryButtonBegin(ButtConfig *bc, int commandkey);
int DTryButton(void);
int DTryButtonEnd(ButtConfig *bc);

#endif
