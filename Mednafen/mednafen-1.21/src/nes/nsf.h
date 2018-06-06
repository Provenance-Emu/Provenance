#ifndef __MDFN_NES_NSF_H
#define __MDFN_NES_NSF_H

class MDFNFILE;

namespace MDFN_IEN_NES
{

struct NSFINFO
{
	std::string GameName, Artist, Copyright, Ripper;
	std::vector<std::string> SongNames;

        unsigned TotalSongs = 0;
        unsigned StartingSong = 0;
        unsigned CurrentSong = 0;
        unsigned TotalChannels = 0 ;
        unsigned VideoSystem = 0;

        uint16 PlayAddr = 0,InitAddr = 0, LoadAddr = 0;
        uint8 BankSwitch[8] = { 0 };
        unsigned SoundChip = 0;

        uint8 *NSFDATA = NULL;
        unsigned NSFMaxBank = 0;
        unsigned NSFSize = 0;
};

typedef struct {
                char ID[5]; /*NESM^Z*/
                uint8 Version;
                uint8 TotalSongs;
                uint8 StartingSong;
                uint8 LoadAddressLow;
                uint8 LoadAddressHigh;
                uint8 InitAddressLow;
                uint8 InitAddressHigh;
                uint8 PlayAddressLow;
                uint8 PlayAddressHigh;
                uint8 GameName[32];
                uint8 Artist[32];
                uint8 Copyright[32];
                uint8 NTSCspeed[2];              // Unused
                uint8 BankSwitch[8];
                uint8 PALspeed[2];               // Unused
                uint8 VideoSystem;
                uint8 SoundChip;
                uint8 Expansion[4];
                uint8 reserve[8];
} NSF_HEADER;

void NSFLoad(Stream *fp, NESGameType *gt) MDFN_COLD;
bool NSF_TestMagic(MDFNFILE *fp);

void DoNSFFrame(void);
void MDFNNES_DrawNSF(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int16 *samples, int32 scount);

// NSF Expansion Chip Set Write Handler
void NSFECSetWriteHandler(int32 start, int32 end, writefunc func);

}

#endif
