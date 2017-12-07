#include "shared.h"
#include "romdb.h"

namespace MDFN_IEN_SMS
{

static const rominfo_t game_list[] = {
    { 0x29822980, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Cosmic Spacehead" },
    { 0xB9664AE1, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Fantastic Dizzy" },
    { 0xA577CE46, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Micro Machines" },
    { 0x8813514B, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Excellent Dizzy (Proto)" },
    { 0xAA140C9C, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Excellent Dizzy (Proto - GG)" },
    { 0xea5c3a6f, MAPPER_CODIES, DISPLAY_PAL, TERRITORY_EXPORT, -1, "Dinobasher Starring Bignose the Caveman (Proto)" },
    { 0xa109a6fe, MAPPER_SEGA,   DISPLAY_PAL, TERRITORY_EXPORT, -1, "Power Strike II" },

    // Game Gear
    {0xd9a7f170, MAPPER_CODIES, DISPLAY_NTSC, TERRITORY_EXPORT, -1, "S.S. Lucifer" },

    {0x5e53c7f7, MAPPER_CODIES, DISPLAY_NTSC, TERRITORY_EXPORT, -1, "Ernie Els Golf" },
    {0xc888222b, MAPPER_CODIES, DISPLAY_NTSC, TERRITORY_EXPORT, CONSOLE_SMS, "Fantastic Dizzy" },
/* Not working?*/    {0x152f0dcc, MAPPER_CODIES, DISPLAY_NTSC, TERRITORY_EXPORT, -1, "Drop Zone" },
/* Not working?*/    {0x8813514b, MAPPER_CODIES, DISPLAY_NTSC, TERRITORY_EXPORT, -1, "Excellent Dizzy Collection" },

    // SG-1000
    { 0x092f29d6, MAPPER_CASTLE, DISPLAY_NTSC, TERRITORY_DOMESTIC, -1,	"The Castle" },
    { (uint32)-1,  -1  	      , -1	    , -1              , -1,	NULL},
};

const rominfo_t *find_rom_in_db(uint32 crc)
{
    /* Look up mapper in game list */
    for(int i = 0; game_list[i].name != NULL; i++)
    {
        if(crc == game_list[i].crc)
	 return(&game_list[i]);
    }

 return(NULL);
}

}
