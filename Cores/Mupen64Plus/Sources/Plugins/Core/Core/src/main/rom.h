/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rom.h                                                   *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 Tillin9                                            *
 *   Copyright (C) 2002 Hacktarux                                          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef __ROM_H__
#define __ROM_H__

#include <stdint.h>

#include "api/m64p_types.h"
#include "md5.h"

#define BIT(bitnr) (1ULL << (bitnr))
#ifdef __GNUC__
#define isset_bitmask(x, bitmask) __extension__ ({ typeof(bitmask) _bitmask = (bitmask); \
                                     (_bitmask & (x)) == _bitmask; })
#else
#define isset_bitmask(x, bitmask) ((bitmask & (x)) == bitmask)
#endif

/* ROM Loading and Saving functions */

m64p_error open_rom(const unsigned char* romimage, unsigned int size);
m64p_error close_rom(void);

extern int g_rom_size;

typedef struct _rom_params
{
   char *cheats;
   m64p_system_type systemtype;
   char headername[21];  /* ROM Name as in the header, removing trailing whitespace */
   unsigned char countperop;
   int disableextramem;
   unsigned int sidmaduration;
} rom_params;

extern m64p_rom_header   ROM_HEADER;
extern rom_params        ROM_PARAMS;
extern m64p_rom_settings ROM_SETTINGS;

/* Supported rom compressiontypes. */
enum 
{
    UNCOMPRESSED,
    ZIP_COMPRESSION,
    GZIP_COMPRESSION,
    BZIP2_COMPRESSION,
    LZMA_COMPRESSION,
    SZIP_COMPRESSION
};

/* Supported rom image types. */
enum 
{
    Z64IMAGE,
    V64IMAGE,
    N64IMAGE
};

/* Supported CIC chips. */
enum
{
    CIC_NUS_6101,
    CIC_NUS_6102,
    CIC_NUS_6103,
    CIC_NUS_6105,
    CIC_NUS_6106
};

/* Supported save types. */
enum
{
    EEPROM_4KB,
    EEPROM_16KB,
    SRAM,
    FLASH_RAM,
    CONTROLLER_PACK,
    NONE
};

/* Rom INI database structures and functions */

/* The romdatabase contains the items mupen64plus indexes for each rom. These
 * include the goodname (from the GoodN64 project), the current status of the rom
 * in mupen, the N64 savetype used in the original cartridge (often necessary for
 * booting the rom in mupen), the number of players (including netplay options),
 * and whether the rom can make use of the N64's rumble feature. Md5, crc1, and
 * crc2 used for rom lookup. Md5s are unique hashes of the ENTIRE rom. Crcs are not
 * unique and read from the rom header, meaning corrupt crcs are also a problem.
 * Crcs were widely used (mainly in the cheat system). Refmd5s allows for a smaller
 * database file and need not be used outside database loading.
 */
typedef struct
{
   char* goodname;
   md5_byte_t md5[16];
   md5_byte_t* refmd5;
   char *cheats;
   unsigned int crc1;
   unsigned int crc2;
   unsigned char status; /* Rom status on a scale from 0-5. */
   unsigned char savetype;
   unsigned char players; /* Local players 0-4, 2/3/4 way Netplay indicated by 5/6/7. */
   unsigned char rumble; /* 0 - No, 1 - Yes boolean for rumble support. */
   unsigned char countperop;
   unsigned char disableextramem;
   unsigned char transferpak; /* 0 - No, 1 - Yes boolean for transferpak support. */
   unsigned char mempak; /* 0 - No, 1 - Yes boolean for mempak support. */
   unsigned int sidmaduration;
   uint32_t set_flags;
} romdatabase_entry;

#define ROMDATABASE_ENTRY_NONE          0ULL
#define ROMDATABASE_ENTRY_GOODNAME      BIT(0)
#define ROMDATABASE_ENTRY_CRC           BIT(1)
#define ROMDATABASE_ENTRY_STATUS        BIT(2)
#define ROMDATABASE_ENTRY_SAVETYPE      BIT(3)
#define ROMDATABASE_ENTRY_PLAYERS       BIT(4)
#define ROMDATABASE_ENTRY_RUMBLE        BIT(5)
#define ROMDATABASE_ENTRY_COUNTEROP     BIT(6)
#define ROMDATABASE_ENTRY_CHEATS        BIT(7)
#define ROMDATABASE_ENTRY_EXTRAMEM      BIT(8)
#define ROMDATABASE_ENTRY_TRANSFERPAK   BIT(9)
#define ROMDATABASE_ENTRY_MEMPAK        BIT(10)
#define ROMDATABASE_ENTRY_SIDMADURATION BIT(11)

typedef struct _romdatabase_search
{
    romdatabase_entry entry;
    struct _romdatabase_search* next_entry;
    struct _romdatabase_search* next_crc;
    struct _romdatabase_search* next_md5;
} romdatabase_search;

typedef struct
{
    int have_database;
    romdatabase_search* crc_lists[256];
    romdatabase_search* md5_lists[256];
    romdatabase_search* list;
} _romdatabase;

void romdatabase_open(void);
void romdatabase_close(void);
/* Should be used by current cheat system (isn't), when cheat system is
 * migrated to md5s, will be fully depreciated.
 */
romdatabase_entry* ini_search_by_crc(unsigned int crc1, unsigned int crc2);

#endif /* __ROM_H__ */

