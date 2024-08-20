snes_event_handler PPU_GetEventHandler(void) MDFN_COLD;
snes_event_handler PPU_GetLineIRQEventHandler(void) MDFN_COLD;
void PPU_SetGetVideoParams(MDFNGI* gi, const unsigned caspect, const unsigned hfilter, const unsigned sls, const unsigned sle) MDFN_COLD;
void PPU_Kill(void) MDFN_COLD;
void PPU_Reset(bool powering_up) MDFN_COLD;
void PPU_ResetTS(void);

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only);

void PPU_StartFrame(EmulateSpecStruct* espec);
//
//
//
uint16 PPU_PeekVRAM(uint32 addr) MDFN_COLD;
uint16 PPU_PeekCGRAM(uint32 addr) MDFN_COLD;
uint8 PPU_PeekOAM(uint32 addr) MDFN_COLD;
uint8 PPU_PeekOAMHI(uint32 addr) MDFN_COLD;
uint32 PPU_GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;

void PPU_PokeVRAM(uint32 addr, uint16 val) MDFN_COLD;
void PPU_PokeCGRAM(uint32 addr, uint16 val) MDFN_COLD;
void PPU_PokeOAM(uint32 addr, uint8 val) MDFN_COLD;
void PPU_PokeOAMHI(uint32 addr, uint8 val) MDFN_COLD;
void PPU_SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

