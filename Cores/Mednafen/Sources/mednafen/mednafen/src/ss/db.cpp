/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* db.cpp:
**  Copyright (C) 2016-2022 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 Grandia could use full cache emulation to fix a hang at the end of disc 1, but
 FMVs make the emulator CPU usage too high; there's also currently a timing bug in
 the VDP1 frame swap/draw start code that causes Grandia to glitch out during gameplay
 with full cache emulation enabled.
*/

#include <mednafen/mednafen.h>
#include <mednafen/FileStream.h>
#include <mednafen/hash/crc.h>

#include "ss.h"
#include "smpc.h"
#include "cart.h"
#include "db.h"

namespace MDFN_IEN_SS
{

static const struct
{
 uint8 id[16];
 unsigned area;
 const char* game_name;
} regiondb[] =
{
 { { 0x10, 0x8f, 0xe1, 0xaf, 0x55, 0x5a, 0x95, 0x42, 0x04, 0x85, 0x7e, 0x98, 0x8c, 0x53, 0x6a, 0x31, }, SMPC_AREA_EU_PAL,	"Preview Sega Saturn Vol. 1 (Europe)" },
 { { 0xed, 0x4c, 0x0b, 0x87, 0x35, 0x37, 0x86, 0x76, 0xa0, 0xf6, 0x32, 0xc6, 0xa4, 0xc3, 0x99, 0x88, }, SMPC_AREA_EU_PAL,	"Primal Rage (Europe)" },
 { { 0x15, 0xfc, 0x3a, 0x82, 0x16, 0xa9, 0x85, 0xa5, 0xa8, 0xad, 0x30, 0xaf, 0x9a, 0xff, 0x03, 0xa9, }, SMPC_AREA_JP,		"Race Drivin' (Japan)" },
 { { 0xe1, 0xdd, 0xfd, 0xa1, 0x8b, 0x47, 0x02, 0x21, 0x36, 0x1e, 0x5a, 0xae, 0x20, 0xc0, 0x59, 0x9f, }, SMPC_AREA_CSA_NTSC,	"Riven - A Sequencia de Myst (Brazil) (Disc 1)" },
 { { 0xbf, 0x5f, 0xf8, 0x5f, 0xf2, 0x0c, 0x35, 0xf6, 0xc9, 0x8d, 0x03, 0xbc, 0x34, 0xd9, 0xda, 0x7f, }, SMPC_AREA_CSA_NTSC,	"Riven - A Sequencia de Myst (Brazil) (Disc 2)" },
 { { 0x98, 0xb6, 0x6e, 0x09, 0xe6, 0xdc, 0x30, 0xe6, 0x55, 0xdb, 0x85, 0x01, 0x33, 0x0c, 0x0b, 0x9c, }, SMPC_AREA_CSA_NTSC,	"Riven - A Sequencia de Myst (Brazil) (Disc 3)" },
 { { 0xa2, 0x34, 0xb0, 0xb9, 0xaa, 0x47, 0x74, 0x1f, 0xd4, 0x1e, 0x35, 0xda, 0x3d, 0xe7, 0x4d, 0xe3, }, SMPC_AREA_CSA_NTSC,	"Riven - A Sequencia de Myst (Brazil) (Disc 4)" },
 { { 0xf7, 0xe9, 0x23, 0x0a, 0x9e, 0x92, 0xf1, 0x93, 0x16, 0x43, 0xf8, 0x6c, 0xe8, 0x21, 0x50, 0x66, }, SMPC_AREA_JP,		"Sega International Victory Goal (Japan)" },
 { { 0x64, 0x75, 0x25, 0x0c, 0xa1, 0x9b, 0x6c, 0x5e, 0x4e, 0xa0, 0x6d, 0x69, 0xd9, 0x0f, 0x32, 0xca, }, SMPC_AREA_EU_PAL,	"Virtua Racing (Europe)" },
 { { 0x0d, 0xe3, 0xfa, 0xfb, 0x2b, 0xb9, 0x6d, 0x79, 0xe0, 0x3a, 0xb7, 0x6d, 0xcc, 0xbf, 0xb0, 0x2c, }, SMPC_AREA_JP,		"Virtua Racing (Japan)" },
 { { 0x6b, 0x29, 0x33, 0xfc, 0xdd, 0xad, 0x8e, 0x0d, 0x95, 0x81, 0xa6, 0xee, 0xfd, 0x90, 0x4b, 0x43, }, SMPC_AREA_EU_PAL,	"Winter Heat (Europe) (Demo)" },
 { { 0x73, 0x91, 0x4b, 0xe1, 0xad, 0x4d, 0xaf, 0x69, 0xc3, 0xeb, 0xb8, 0x43, 0xee, 0x3e, 0xb5, 0x09, }, SMPC_AREA_EU_PAL,	"WWF WrestleMania - The Arcade Game (Europe) (Demo)" },
};

static const struct
{
 const char* sgid;
 const char* sgname;
 int cart_type;
 const char* game_name;
 const char* purpose;
 uint8 fd_id[16];
} cartdb[] =
{
 //
 //
 // NetLink Modem TODO:
 { "MK-81218", NULL, CART_NONE, "Daytona USA CCE Net Link Edition", gettext_noop("Reserved for future modem support.") },
 { "MK-81071", NULL, CART_NONE, "Duke Nukem 3D", gettext_noop("Reserved for future modem support.") },
 { "T-319-01H", NULL, CART_NONE, "PlanetWeb Browser (multiple versions)", gettext_noop("Reserved for future modem support.") },
 { "MK-81070", NULL, CART_NONE, "Saturn Bomberman", gettext_noop("Reserved for future modem support.") },
 { "MK-81215", NULL, CART_NONE, "Sega Rally Championship Plus NetLink Edition", gettext_noop("Reserved for future modem support.") },
 { "MK-81072", NULL, CART_NONE, "Virtual On NetLink Edition", gettext_noop("Reserved for future modem support.") },
 //
 //
 // Japanese modem TODO:
 { "GS-7106", NULL, CART_NONE, "Dennou Senki Virtual On (SegaNet)", gettext_noop("Reserved for future modem support.") },
 { "GS-7114", NULL, CART_NONE, "Dragon's Dream (Japan)", gettext_noop("Reserved for future modem support.") },
 { "GS-7105", NULL, CART_NONE, "Habitat II (Japan)", gettext_noop("Reserved for future modem support.") },
 { "GS-7101", NULL, CART_NONE, "Pad Nifty (Japan)", gettext_noop("Reserved for future modem support.") },
 { "GS-7113", NULL, CART_NONE, "Puzzle Bobble 3 (SegaNet)", gettext_noop("Reserved for future modem support.") },
 { "T-14305G", NULL, CART_NONE, "Saturn Bomberman (SegaNet)", gettext_noop("Reserved for future modem support.") },
 { "T-31301G", NULL, CART_NONE, "SegaSaturn Internet Vol. 1 (Japan)", gettext_noop("Reserved for future modem support.") },
 //
 //
 // ROM carts:
 { "MK-81088", NULL, CART_KOF95, "King of Fighters '95, The (Europe)", gettext_noop("Game requirement.") },
 { "T-3101G", NULL, CART_KOF95, "King of Fighters '95, The (Japan)", gettext_noop("Game requirement.") },
 { "T-13308G", NULL, CART_ULTRAMAN, "Ultraman - Hikari no Kyojin Densetsu (Japan)", gettext_noop("Game requirement.") },
 //
 //
 // 1MiB RAM cart:
 { "T-1521G", NULL, CART_EXTRAM_1M, "Astra Superstars (Japan)" },	// Would 4MiB be better?
 { "T-9904G", NULL, CART_EXTRAM_1M, "Cotton 2 (Japan)" },
 { "T-1217G", NULL, CART_EXTRAM_1M, "Cyberbots (Japan)" },
 { "GS-9107", NULL, CART_EXTRAM_1M, "Fighter's History Dynamite (Japan)", gettext_noop("Game requirement.") },
 { "T-20109G", NULL, CART_EXTRAM_1M, "Friends (Japan)" },		// Would 4MiB be better?
 { "T-14411G", NULL, CART_EXTRAM_1M, "Groove on Fight (Japan)", gettext_noop("Game requirement.") },
 { "T-7032H-50", NULL, CART_EXTRAM_1M, "Marvel Super Heroes (Europe)" },
 { "T-1215G", NULL, CART_EXTRAM_1M, "Marvel Super Heroes (Japan)" },
 { "T-3111G", NULL, CART_EXTRAM_1M, "Metal Slug (Japan)", gettext_noop("Game requirement.") },
 { "T-22205G", NULL, CART_EXTRAM_1M, "NOël 3 (Japan)" },
 { "T-20114G", NULL, CART_EXTRAM_1M, "Pia Carrot e Youkoso!! 2 (Japan)" },
 { "T-3105G", NULL, CART_EXTRAM_1M, "Real Bout Garou Densetsu (Japan)", gettext_noop("Game requirement.") }, //  Incompatible with 4MiB extended RAM cart.
 { "T-99901G", "REAL BOUT", CART_EXTRAM_1M, "Real Bout Garou Densetsu Demo (Japan)", gettext_noop("Game requirement.") }, //  Incompatible with 4MiB extended RAM cart.
 { "T-3119G", NULL, CART_EXTRAM_1M, "Real Bout Garou Densetsu Special (Japan)", gettext_noop("Game requirement.") },
 { "T-3116G", NULL, CART_EXTRAM_1M, "Samurai Spirits - Amakusa Kourin (Japan)", gettext_noop("Game requirement.") }, // Incompatible with 4MiB extended RAM cart.
 { "T-3104G", NULL, CART_EXTRAM_1M, "Samurai Spirits - Zankurou Musouken (Japan)", gettext_noop("Game requirement.") },
 { "610636008", NULL, CART_EXTRAM_1M,"Tech Saturn 1997.6 (Japan)", gettext_noop("Required by \"Groove on Fight\" demo.") },
 { "T-16509G", NULL, CART_EXTRAM_1M, "Super Real Mahjong P7 (Japan)" },
 { "T-16510G", NULL, CART_EXTRAM_1M, "Super Real Mahjong P7 (Japan)" },	// Would 4MiB be better?
 { "T-3108G", NULL, CART_EXTRAM_1M, "The King of Fighters '96 (Japan)", gettext_noop("Game requirement.") },
 { "T-3121G", NULL, CART_EXTRAM_1M, "The King of Fighters '97 (Japan)", gettext_noop("Game requirement.") },
 { "T-1515G", NULL, CART_EXTRAM_1M, "Waku Waku 7 (Japan)", gettext_noop("Game requirement.") },
 //
 //
 // 4MiB RAM cart:
 { "T-1245G", NULL, CART_EXTRAM_4M, "Dungeons and Dragons Collection (Japan)", gettext_noop("Game requirement(\"Shadow over Mystara\").") },
 { "T-1248G", NULL, CART_EXTRAM_4M, "Final Fight Revenge (Japan)", gettext_noop("Game requirement.") },
 { "T-1238G", NULL, CART_EXTRAM_4M, "Marvel Super Heroes vs. Street Fighter (Japan)", gettext_noop("Game requirement.") },
 { "T-1230G", NULL, CART_EXTRAM_4M, "Pocket Fighter (Japan)" },
 { "T-1246G", NULL, CART_EXTRAM_4M, "Street Fighter Zero 3 (Japan)", gettext_noop("Game requirement.") },
 { "T-1229G", NULL, CART_EXTRAM_4M, "Vampire Savior (Japan)", gettext_noop("Game requirement.") },
 { "T-1226G", NULL, CART_EXTRAM_4M, "X-Men vs. Street Fighter (Japan)", gettext_noop("Game requirement.") },
 //
 //
 //
 { nullptr, NULL, CART_CS1RAM_16M, "Heart of Darkness (Prototype)", gettext_noop("Game requirement(though it's probable the original dev cart was only around 6 to 8MiB)."), { 0x4a, 0xf9, 0xff, 0x30, 0xea, 0x54, 0xfe, 0x3a, 0x79, 0xa7, 0x68, 0x69, 0xae, 0xde, 0x55, 0xbb } },
 { nullptr, NULL, CART_CS1RAM_16M, "Heart of Darkness (Prototype)", gettext_noop("Game requirement(though it's probable the original dev cart was only around 6 to 8MiB)."), { 0xf1, 0x71, 0xc3, 0xe4, 0x69, 0xd5, 0x99, 0x93, 0x94, 0x09, 0x05, 0xfc, 0x29, 0xd3, 0x8a, 0x59 } },
 //
 //
 // Backup memory cart:
 { "T-16804G", NULL, CART_BACKUP_MEM, "Dezaemon 2 (Japan)", gettext_noop("Allows saving.") },	// !
 { "GS-9123", NULL, CART_BACKUP_MEM,	"Die Hard Trilogy (Japan)", gettext_noop("Game will crash when running with a RAM expansion cart.") }, // !
 { "T-16103H", NULL, CART_BACKUP_MEM,	"Die Hard Trilogy (Europe/USA)", gettext_noop("Game will crash when running with a RAM expansion cart.") }, // !
 { "T-26104G", NULL, CART_BACKUP_MEM, "Kouryuu Sangoku Engi (Japan)" }, // !
 { "GS-9197", NULL, CART_BACKUP_MEM,	"Sega Ages - Galaxy Force II", gettext_noop("Allows saving replay data.") }, // !
#if 0
 { "T-9527G", NULL, CART_BACKUP_MEM,	"Akumajou Dracula X - Gekka no Yasoukyoku (Japan)" },
 { "T-1507G", NULL, CART_BACKUP_MEM,	"Albert Odyssey (Japan)" },
 { "T-12705H", NULL, CART_BACKUP_MEM,	"Albert Odyssey (USA)" },
 { "T-1209G", NULL, CART_BACKUP_MEM,	"Arthur to Astaroth no Nazomakaimura - Incredible Toons (Japan)" },
 { "T-33901G", NULL, CART_BACKUP_MEM,	"Baroque (Japan)" },
 { "T-20113G", NULL, CART_BACKUP_MEM, "Black Matrix (Japan)" },
 { "T-20115G", NULL, CART_BACKUP_MEM, "Black Matrix (Japan)" },
 { "T-4315G", NULL, CART_BACKUP_MEM,	"Blue Breaker (Japan)" },
 { "GS-9174", NULL, CART_BACKUP_MEM,	"Burning Rangers (Japan)" },
 { "MK-81803", NULL, CART_BACKUP_MEM,	"Burning Rangers (Europe/USA)" },
 { "610-6431", NULL, CART_BACKUP_MEM,	"Christmas NiGHTS into Dreams (Japan)" },
 { "610-6483", NULL, CART_BACKUP_MEM,	"Christmas NiGHTS into Dreams (Europe)" },
 { "MK-81067", NULL, CART_BACKUP_MEM,	"Christmas NiGHTS into Dreams (USA)" },
 { "T-22101G", NULL, CART_BACKUP_MEM,	"Dark Savior (Japan)" },
 { "MK-81304", NULL, CART_BACKUP_MEM,	"Dark Savior (Europe/USA)" },
 { "GS-9028", NULL, CART_BACKUP_MEM,	"Dragon Force (Japan)" }, // ~
 { "T-12703H", NULL, CART_BACKUP_MEM,	"Dragon Force (USA)" }, // ~
 { "MK-8138250", NULL, CART_BACKUP_MEM,"Dragon Force (Europe)" }, // ~
 { "GS-9184", NULL, CART_BACKUP_MEM,	"Dragon Force II (Japan)" }, // ~
 { "T-31503G", NULL, CART_BACKUP_MEM,	"Falcom Classics (Japan)" },
 { "T-31504G", NULL, CART_BACKUP_MEM,	"Falcom Classics II Genteiban (Japan)" },
 { "T-31505G", NULL, CART_BACKUP_MEM,	"Falcom Classics II (Japan)" },
 { "T-9525G", NULL, CART_BACKUP_MEM,	"Gensou Suikoden (Japan)" },
 { "T-4507G", NULL, CART_BACKUP_MEM,	"Grandia (Japan)" },
 { "T-4512G", NULL, CART_BACKUP_MEM,	"Grandia - Digital Museum (Japan)" },
 { "T-19710G", NULL, CART_BACKUP_MEM,	"GunBlaze-S (Japan)" },
 { "T-18612G", NULL, CART_BACKUP_MEM,	"Hexen (Japan)", gettext_noop("Allows saving.") }, // !
 { "T-25406H", NULL, CART_BACKUP_MEM,	"Hexen (USA)", gettext_noop("Allows saving.") }, // !
 { "T-25405H50", NULL, CART_BACKUP_MEM,"Hexen (Europe)", gettext_noop("Allows saving.") }, // !
 { "T-2502G", NULL, CART_BACKUP_MEM,	"Langrisser III (Japan)" },
 { "T-2505G", NULL, CART_BACKUP_MEM,	"Langrisser IV (Japan)" },
 { "T-2509G", NULL, CART_BACKUP_MEM,	"Langrisser V (Japan)" },
 { "T-37101G", NULL, CART_BACKUP_MEM,	"Legend of Heroes I & II, The - Eiyuu Densetsu (Japan)" },
 { "MK-81302", NULL, CART_BACKUP_MEM,	"Legend of Oasis, The (USA) / Story of Thor 2, The (Europe)" },
 { "GS-9053", NULL, CART_BACKUP_MEM,	"Thor - Seireioukiden (Japan)" },
 { "T-27901G", NULL, CART_BACKUP_MEM,	"Lunar - Silver Star Story (Japan)" },
 { "T-27904G", NULL, CART_BACKUP_MEM,	"Lunar - Silver Star Story MPEG (Japan)" },
 { "T-27906G", NULL, CART_BACKUP_MEM,	"Lunar 2 - Eternal Blue (Japan)" },
 { "T-6607G", NULL, CART_BACKUP_MEM,	"Madou Monogatari (Japan)" },
 { "GS-9018", NULL, CART_BACKUP_MEM,	"Magic Knight Rayearth (Japan)" },
 { "T-12706H", NULL, CART_BACKUP_MEM,	"Magic Knight Rayearth (USA)" },
 { "T-27902G", NULL, CART_BACKUP_MEM,	"Mahou Gakuen Lunar (Japan)" },
 { "T-1214G", NULL, CART_BACKUP_MEM,	"Rockman 8 (Japan)" },
 { "T-1216H", NULL, CART_BACKUP_MEM,	"Mega Man 8 (USA)" },
 { "T-1210G", NULL, CART_BACKUP_MEM,	"Rockman X3 (Japan)" },
 { "T-7029H-50", NULL, CART_BACKUP_MEM,"Mega Man X3 (Europe)" },
 { "T-1221G", NULL, CART_BACKUP_MEM,	"Rockman X4 (Japan)" },
 { "T-1219H", NULL, CART_BACKUP_MEM,	"Mega Man X4 (USA)" },
 { "T-1501G", NULL, CART_BACKUP_MEM,	"Myst (Japan)" },
 { "T-26801H08", NULL, CART_BACKUP_MEM,"Myst (Korea)" },
 { "T-8101H", NULL, CART_BACKUP_MEM,	"Myst (USA)" },
 { "MK-81081", NULL, CART_BACKUP_MEM,	"Myst (Europe)" },
 { "GS-9046", NULL, CART_BACKUP_MEM,	"NiGHTS into Dreams (Japan)" },
 { "MK-81020", NULL, CART_BACKUP_MEM,	"NiGHTS into Dreams (Europe/USA)" },
 { "GS-9076", NULL, CART_BACKUP_MEM,	"Panzer Dragoon RPG (Japan)" },
 { "MK-81307", NULL, CART_BACKUP_MEM,	"Panzer Dragoon Saga (Europe/USA)" },
 { "T-26112G", NULL, CART_BACKUP_MEM,	"Prisoner of Ice (Japan)" }, // ~
 { "T-1219G", NULL, CART_BACKUP_MEM,	"Bio Hazard (Japan)" },
 { "T-1221H", NULL, CART_BACKUP_MEM,	"Resident Evil (USA)" },
 { "MK-81092", NULL, CART_BACKUP_MEM,	"Resident Evil (Europe)" },
 { "T-7601G", NULL, CART_BACKUP_MEM,	"Sangokushi IV (Japan)" },
 { "T-7644G", NULL, CART_BAKCUP_MEM,	"Sangokushi IV with Power-Up Kit (Japan)" },
 { "T-7601H", NULL, CART_BACKUP_MEM,  "Romance of the Three Kingdoms IV - Wall of Fire (USA)" },
 { "MK-81383", NULL, CART_BACKUP_MEM,	"Shining Force III (Europe/USA)" }, // ~
 { "GS-9175", NULL, CART_BACKUP_MEM,	"Shining Force III - Scenario 1 (Japan)" }, // ~
 { "GS-9188", NULL, CART_BACKUP_MEM,	"Shining Force III - Scenario 2 (Japan)" }, // ~
 { "GS-9203", NULL, CART_BACKUP_MEM,	"Shining Force III - Scenario 3 (Japan)" }, // ~
 { "T-33101G", NULL, CART_BACKUP_MEM,	"Shining the Holy Ark (Japan)" },
 { "MK-81306", NULL, CART_BACKUP_MEM,	"Shining the Holy Ark (Europe/USA)" },
 { "GS-9057", NULL, CART_BACKUP_MEM,	"Shining Wisdom (Japan)" },
 { "T-12702H", NULL, CART_BACKUP_MEM,	"Shining Wisdom (USA)" },
 { "MK-81381", NULL, CART_BACKUP_MEM,	"Shining Wisdom (Europe)" },
 { "T-14322G", NULL, CART_BACKUP_MEM,	"Shiroki Majo - Mou Hitotsu no Eiyuu Densetsu (Japan)" },
 { "GS-9027", NULL, CART_BACKUP_MEM,	"SimCity 2000 (Japan)" }, // ~
 { "T-12601H", NULL, CART_BACKUP_MEM,	"SimCity 2000 (USA)" }, // ~
 { "MK-81580", NULL, CART_BACKUP_MEM,	"SimCity 2000 (Europe)" }, // ~
 { "T-27903G", NULL, CART_BACKUP_MEM,	"Slayers Royal (Japan)" },
 { "T-27907G", NULL, CART_BACKUP_MEM,	"Slayers Royal 2 (Japan)" },
 { "GS-9170", NULL, CART_BACKUP_MEM,	"Sonic R (Japan)" },
 { "MK-81800", NULL, CART_BACKUP_MEM,	"Sonic R (Europe/USA)" },
 { "T-16609G", NULL, CART_BACKUP_MEM,	"Sorvice (Japan)" },
 { "T-9526G", NULL, CART_BACKUP_MEM,	"Vandal Hearts - Ushinawareta Kodai Bunmei (Japan)" },
 { "T-10623G", NULL, CART_BACKUP_MEM,	"WarCraft II (Japan)" }, // ~
 { "T-5023H", NULL, CART_BACKUP_MEM,	"WarCraft II (USA)" }, // ~
 { "T-5023H-50", NULL, CART_BACKUP_MEM,"WarCraft II (Europe)" }, // ~
#endif
};

static const struct
{
 const char* sgid;
 const char* sgname;
 const char* sgarea;
 unsigned mode;
 const char* game_name;
 const char* purpose;
 uint8 fd_id[16];
} cemdb[] =
{
 { "T-9705H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Area 51 (USA)", gettext_noop("Fixes game hang.") },
 { "T-25408H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Area 51 (Europe)", gettext_noop("Fixes game hang.") },
 { "MK-81036",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Clockwork Knight 2 (USA)", gettext_noop("Fixes game hang that occurred when some FMVs were played.") },
 { "T-01304H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Creature Shock - Special Edition (USA)", gettext_noop("Fixes game crash when trying to start a level.") },
 { "T-30304G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "DeJig - Lassen Art Collection (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "T-19801G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Doraemon - Nobita to Fukkatsu no Hoshi (Japan)", gettext_noop("Fixes blank Game Over screen.") },
 { "GS-9184",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Dragon Force II (Japan)", gettext_noop("Fixes math and game logic errors during battles.") },
 { "T-18504G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Father Christmas (Japan)", gettext_noop("Fixes stuck music and voice acting.") },
 { "GS-9101",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Fighting Vipers (Japan)", gettext_noop("Fixes computer-controlled opponent turning into a ghost statue.") },
 { "MK-81041",  NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Fighting Vipers (Europe/USA)", gettext_noop("Fixes computer-controlled opponent turning into a ghost statue.") },
 { "T-7309G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Formula Grand Prix - Team Unei Simulation (Japan)", gettext_noop("Fixes game hang.") },
 { "MK-81045",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Golden Axe - The Duel (Europe/USA)", gettext_noop("Fixes flickering title screen.") },
 { "GS-9041",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Golden Axe - The Duel (Japan)", gettext_noop("Fixes flickering title screen.") },
 { "GS-9173",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"House of the Dead (Japan)", gettext_noop("Fixes game crash on lightgun calibration screen.") },
 { "GS-9017",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Kanzen Chuukei Pro Yakyuu Greatest Nine (Japan)", gettext_noop("Fixes game hang.") },
 { "GS-9055",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Linkle Liver Story (Japan)", gettext_noop("Fixes game crash when going to the world map.") },
 { "T-5006H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Magic Carpet (Europe)", gettext_noop("Fixes game hang.") },
 { "T-25302G1", NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Mahjong Doukyuusei Special (Japan)",	gettext_noop("Fixes missing background layer on disc 2.") },
 { "T-25302G2", NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Mahjong Doukyuusei Special (Japan)",	gettext_noop("Fixes missing background layer on disc 2.") },
 { "MK-81210",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Manx TT SuperBike (Europe)", gettext_noop("Fixes game crash during optional intro movie.") },
 { "T-28901G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Mujintou Monogatari R - Futari no Love Love Island (Japan)", gettext_noop("Fixes glitches when character graphics change.") },
 { "T-14415G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Ronde (Japan)", gettext_noop("Fixes missing graphics on the title screen, main menu, and elsewhere.") },
 { "610602002",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Saturn Super Vol. 2 (Japan)", gettext_noop("Fixes flickering title screen in the \"Golden Axe - The Duel\" demo.") },
 { "81600",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Sega Saturn Choice Cuts (USA)", gettext_noop("Fixes FMV playback hangs and playback failures.") },
 { "610680501", NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Segakore Sega Bible Mogitate SegaSaturn (Japan)", gettext_noop("Fixes graphical glitch on the character select screen in the \"Zero Divide\" demo.") },
 { "T-18703G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Shunsai (Japan)", gettext_noop("Fixes various graphical glitches.") },
 { "T-7001H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Spot Goes to Hollywood (USA)", gettext_noop("Fixes hang at corrupted \"Burst\" logo.") },
 { "T-7014G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Spot Goes to Hollywood (Japan)", gettext_noop("Fixes hang at corrupted \"Burst\" logo.") },
 // Nooo, causes glitches: { "T-7001H-50",CPUCACHE_EMUMODE_DATA_CB,	"Spot Goes to Hollywood (Europe)
 { "T-1206G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Street Fighter Zero (Japan)", gettext_noop("Fixes weird color/palette issues during game startup.") },
 { "T-1246G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Street Fighter Zero 3 (Japan)", gettext_noop("") },	// ? ? ?
 { "T-1215H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Super Puzzle Fighter II Turbo (USA)", gettext_noop("Fixes color/brightness and other graphical issues.") },
 { "T-5001H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Theme Park (Europe)", gettext_noop("Fixes hang during FMV.") },
 { "T-1808G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Thunder Force Gold Pack 2 (Japan)", gettext_noop("Fixes hang when pausing the game under certain conditions in \"Thunder Force AC\".") },
 { "GS-9079","VF. KIDS",NULL,CPUCACHE_EMUMODE_DATA_CB,"Virtua Fighter Kids (Japan/Europe)", gettext_noop("Fixes FMV glitches.") },
 { "GS-9113","VF. KIDS",NULL,CPUCACHE_EMUMODE_DATA_CB,"Virtua Fighter Kids (Korea/Java Tea Original)", gettext_noop("Fixes FMV glitches and/or malfunction of computer-controlled player.") },
 { "MK-81049","VF. KIDS",NULL,CPUCACHE_EMUMODE_DATA_CB,"Virtua Fighter Kids (USA)", gettext_noop("Fixes FMV glitches.") },
 { "T-2206G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Virtual Mahjong (Japan)", gettext_noop("Fixes graphical glitches on the character select screen.") },
 { "T-15005G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Virtual Volleyball (Japan)", gettext_noop("Fixes invisible menu items and hang.") },
 { "T-18601H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"WipEout (USA)", gettext_noop("Fixes hang when trying to exit gameplay back to the main menu.") },
 { "T-18603G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"WipEout (Japan)", gettext_noop("Fixes hang when trying to exit gameplay back to the main menu.") },
 { "T-11301H",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"WipEout (Europe)", gettext_noop("Fixes hang when trying to exit gameplay back to the main menu.") },
 { "GS-9061",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"Hideo Nomo World Series Baseball (Japan)", gettext_noop("Fixes severe gameplay logic glitches.") },
 { "MK-81109",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB,	"World Series Baseball (Europe/USA)", gettext_noop("Fixes severe gameplay logic glitches.") },
 { "T-31601G",	NULL, NULL, CPUCACHE_EMUMODE_DATA_CB, "Zero Divide - The Final Conflict (Japan)", gettext_noop("Fixes graphical glitch on the character select screen.") },
 //{ "MK-81019", NULL, NULL, CPUCACHE_EMUMODE_DATA },	// Astal (USA)
 //{ "GS-9019",  CPUCACHE_EMUMODE_DATA },	// Astal (Japan)

 { "T-15906H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "3D Baseball (USA)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-18003G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "3D Baseball - The Majors (Japan)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-1507G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Albert Odyssey (Japan)", gettext_noop("") },
 { "T-12705H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Albert Odyssey (USA)", gettext_noop("Fixes battle text truncation.") },
 //{ "MK-81501",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Baku Baku Animal (Europe)", gettext_noop("Fixes hang when trying to watch a movie in the \"Movie Viewer\".") },
 { "T-16201H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Corpse Killer (USA)", gettext_noop("Fixes glitchy rotation-zoom effect.") },
 { "T-8124H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Crow, The (USA)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8124H-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Crow, The (Europe)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8124H-18",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Crow, The (Germany)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-36101G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Dark Seed II (Japan)", gettext_noop("Fixes game hang.") },
 { "GS-9123",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Die Hard Trilogy (Japan)", gettext_noop("Fixes game hang.") },
 { "T-16103H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Die Hard Trilogy (Europe/USA)", gettext_noop("Fixes game hang.") },
 // Not needed in 1.26.0, and actually causes a game hang, probably due to lack of SCI emulation messing up game timing: { "T-13331G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Digital Monster Version S (Japan)", gettext_noop("Fixes game hang.") },
 { "T-29101G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Gal Jan (Japan)", gettext_noop("Fixes game hang after game ends.") },
 { "T-4504G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Gambler Jiko Chuushinha - Tokyo Mahjongland", gettext_noop("Fixes flickering octopus screen.") },
 { "T-13310G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "GeGeGe no Kitarou (Japan)", gettext_noop("Fixes game hang.") },
 { "T-15904G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Gex (Japan)",		gettext_noop("Fixes minor FMV glitches.")  },
 { "T-15904H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Gex (USA)",		gettext_noop("Fixes minor FMV glitches.") },
 { "T-15904H50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Gex (Europe)",		gettext_noop("Fixes minor FMV glitches.") },
 { "T-24301G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Horror Tour (Japan)",	gettext_noop("Fixes graphical glitches on the save and load screens.") },
 { "T-22403G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Irem Arcade Classics (Japan)", gettext_noop("Fixes hang when trying to start \"Zippy Race\".") },
 { "GS-9142",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Kidou Senkan Nadesico - Yappari Saigo wa Ai ga Katsu", gettext_noop("Fixes game hang.") },
 { "GS-9162",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "The Lost World - Jurassic Park (Japan)", gettext_noop("Fixes most graphical glitches in rock faces.") },
 { "MK-81065",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "The Lost World - Jurassic Park (Europe/USA)", gettext_noop("Fixes most graphical glitches in rock faces.") },
 { "T-27901G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Lunar - Silver Star Story (Japan)", gettext_noop("Fixes FMV flickering.") },
 { "MK-81103",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "NBA Action (USA)", gettext_noop("Fixes minor FMV glitches.") },
 { "MK81103-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "NBA Action (Europe)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8105G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "NFL Quarterback Club 96 (Japan)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8109H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "NFL Quarterback Club 96 (USA)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8109H-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "NFL Quarterback Club 96 (Europe)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-7664G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Nobunaga no Yabou Shouseiroku (Japan)", gettext_noop("Fixes game hang.") },
 { "T-9510G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Policenauts (Japan)",	gettext_noop("Fixes screen flickering on disc 2.") },
 { "T-25416H50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Rampage - World Tour (Europe)", gettext_noop("Fixes game hang.") }, 
 { "T-99901G", "REAL BOUT", NULL, CPUCACHE_EMUMODE_FULL, "Real Bout Garou Densetsu Demo (Japan)", gettext_noop("") },
 { "T-3105G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Real Bout Garou Densetsu (Japan)", gettext_noop("Fixes game hang.") },
 { "T-8107H-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Revolution X - Music Is the Weapon (Europe)", gettext_noop("Fixes game hang.") },
 { "T-8107H-18",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Revolution X - Music Is the Weapon (Germany)", gettext_noop("Fixes game hang.") },
 { "T-37401G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Senken Kigyouden (Japan)", gettext_noop("Fixes dialogue text truncation.") },
 { "T-37401H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Xian Jian Qi Xia Zhuan (Taiwan)", gettext_noop("Fixes dialogue text truncation.") },
 { "T-30902G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Senkutsu Katsuryu Taisen - Chaos Seed (Japan)", gettext_noop("Fixes inability to skip intro FMV.") },
 { "T-159056",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Slam 'n Jam 96 (Japan)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-159028H", NULL, NULL, CPUCACHE_EMUMODE_FULL, "Slam 'n Jam 96 (USA)",	gettext_noop("Fixes minor FMV glitches.") },
 { "T-15902H50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Slam 'n Jam 96 (Europe)", gettext_noop("Fixes minor FMV glitches.") },
 { "T-8119G", 	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Space Jam (Japan)", 	gettext_noop("Fixes game crash.") },
 { "T-8125H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Space Jam (USA)", 	gettext_noop("Fixes game crash.") },
 { "T-8125H-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Space Jam (Europe)", 	gettext_noop("Fixes game crash.") },
 { "T-1807G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Thunder Force Gold Pack 1 (Japan)", gettext_noop("In \"Thunder Force III\", fixes explosion graphic glitches throughout the game and ship sprite glitches in the ending sequence.") },
 { "T-15903G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Titan Wars (Japan)",	gettext_noop("Fixes minor FMV glitches.") },
 { "T-15911H",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Solar Eclipse (USA)",	gettext_noop("Fixes minor FMV glitches.") },
 { "T-15911H50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Titan Wars (Europe)",	gettext_noop("Fixes minor FMV glitches.") },
 { "MK-81015",	NULL, "E",  CPUCACHE_EMUMODE_FULL, "Virtua Cop (Europe)", gettext_noop("Fixes game hang.") },
 { "MK-81043",	NULL, "E",  CPUCACHE_EMUMODE_FULL, "Virtua Cop 2 (Europe)", gettext_noop("Fixes game hang.") },
 { "GS-9001", 	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "MK-81005",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter (USA)", gettext_noop("Fixes graphical glitches.") },
 { "MK_8100550",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter (Europe)", gettext_noop("Fixes graphical glitches.") },
 { "GS-9039",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter Remix (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "MK-81023",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter Remix (USA)", gettext_noop("Fixes graphical glitches.") },
 { "MK-8102350",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter Remix (Europe)", gettext_noop("Fixes graphical glitches.") },
 { "SG-7103",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Virtua Fighter Remix (SegaNet)", gettext_noop("Fixes graphical glitches.") },
 { "T-36102G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Whizz (Japan)", 	gettext_noop("Fixes quasi-random hangs during startup.") },
 { "T-9515H-50",NULL, NULL, CPUCACHE_EMUMODE_FULL, "Whizz (Europe)", 	gettext_noop("Fixes quasi-random hangs during startup.") },
 { "T-28004G",	NULL, NULL, CPUCACHE_EMUMODE_FULL, "Yu-No (Japan)",	gettext_noop("Fixes FMV ending too soon.") },
 //
 // DMA overhead sensitive games, may be fragile:
 //
#if 0
 { "T-38001G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Another Memories (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27810G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Device Reign (Japan)",	gettext_noop("Fixes game hang.") },
 { "T-30002G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Real Sound - Kaze no Regret (Japan)", gettext_noop("Fixes game hang.") },
 { "T-13324G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"SD Gundam G Century S (Japan)", gettext_noop("Fixes game hang.") },
 { "T-26413G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Super Tempo (Japan)",	gettext_noop("Fixes game hang.") },
 { "T-17703G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Tennis Arena (Japan)",	gettext_noop("Fixes game hang.") },
 { "T-32508G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Tilk - Aoi Umi kara Kita Shoujo (Japan)", gettext_noop("Fixes game hang.") },
 { "6106602",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu Gensoukyoku Demo (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27804G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu Gensoukyoku (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27806G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu no Kobako Official Collection (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27807G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu Gensoukyoku 2nd Album (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27808G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu Gensoukyoku ensemble (Japan)", gettext_noop("Fixes game hang.") },
 { "T-27809G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Yuukyuu Gensoukyoku ensemble 2 (Japan)", gettext_noop("Fixes game hang.") },
 { "T-21401G",	NULL, NULL, CPUCACHE_EMUMODE_FULL,		"Zero4 Champ DooZy-J Type-R (Japan)", gettext_noop("Fixes game hang.") },
#endif
};

void DB_Lookup(const char* path, const char* sgid, const char* sgname, const char* sgarea, const uint8* fd_id, unsigned* const region, int* const cart_type, unsigned* const cpucache_emumode)
{
 for(auto& re : regiondb)
 {
  if(!memcmp(re.id, fd_id, 16))
  {
   *region = re.area;
   break;
  }
 }

 for(auto& ca : cartdb)
 {
  bool match;

  if(ca.sgid)
  {
   match = !strcmp(ca.sgid, sgid);

   if(ca.sgname)
    match &= !strcmp(ca.sgname, sgname);
  }
  else
   match = !memcmp(ca.fd_id, fd_id, 16);

  if(match)
  {
   *cart_type = ca.cart_type;
   break;
  }
 }

 for(auto& c : cemdb)
 {
  bool match;

  if(c.sgid)
  {
   match = !strcmp(c.sgid, sgid);

   if(c.sgname)
    match &= !strcmp(c.sgname, sgname);

   if(c.sgarea)
    match &= !strcmp(c.sgarea, sgarea);
  }
  else
   match = !memcmp(c.fd_id, fd_id, 16);

  if(match)
  {
   *cpucache_emumode = c.mode;
   break;
  }
 }
}

static const struct
{
 const char* sgid;
 unsigned horrible_hacks;
 const char* game_name;
 const char* purpose;
 uint8 fd_id[16];
} hhdb[] =
{
 { "GS-9126", HORRIBLEHACK_NOSH2DMAPENALTY,	"Fighters Megamix (Japan)", gettext_noop("Fixes hang after watching or aborting FMV playback.") },
 { "MK-81073", HORRIBLEHACK_NOSH2DMAPENALTY,	"Fighters Megamix (Europe/USA)", gettext_noop("Fixes hang after watching or aborting FMV playback.") },

 { "T-4507G", HORRIBLEHACK_VDP1VRAM5000FIX,	"Grandia (Japan)", gettext_noop("Fixes hang at end of first disc.") },

 { "T-1507G",	HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,"Albert Odyssey (Japan)", gettext_noop("Partially fixes battle text truncation.") },
 { "T-12705H",	HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,"Albert Odyssey (USA)", gettext_noop("Partially fixes battle text truncation.") },
 { "T-8150H", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"All-Star Baseball 97 (USA)", gettext_noop("Fixes texture glitches.") },
 { "T-9703H", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Arcade's Greatest Hits (USA)", gettext_noop("Fixes flickering credits text.") },
 { "T-9706H", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Arcade's Greatest Hits - Atari Collection 1 (USA)", gettext_noop("Fixes flickering credits text.") },
 { "6106856", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Burning Rangers Taikenban (Japan)", gettext_noop("Fixes flickering rescue text.") },
 { "GS-9174", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Burning Rangers (Japan)", gettext_noop("Fixes flickering rescue text.") },
 { "MK-81803", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Burning Rangers (Europe/USA)", gettext_noop("Fixes flickering rescue text.") },
 { "T-31505G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Falcom Classics II (Japan)", gettext_noop("Fixes FMV tearing in \"Ys II\".") },
 { "T-8111G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Frank Thomas Big Hurt Baseball (Japan)", gettext_noop("Reduces graphical glitches.") },
 { "T-8138H", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Frank Thomas Big Hurt Baseball (USA)", gettext_noop("Reduces graphical glitches.") }, // Probably need more-accurate VDP1 draw timings to fix the glitches completely.
 { "T-23001H", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Herc's Adventures (USA)", gettext_noop("Fixes some sprite flickering and tearing.") },
 { "T-9504G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Tokimeki Memorial - Forever with You (Japan)", gettext_noop("Fixes glitchy frames on the Konami intro arm sprite.") },
 { "T-15006G",  HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Kaitei Daisensou (Japan)", gettext_noop("Fixes FMV tearing.") },
 { "T-10001G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "In The Hunt (Europe/USA)", gettext_noop("Fixes FMV tearing.") },
 { "GS-9001", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Virtua Fighter (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "MK-81005", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Virtua Fighter (USA)", gettext_noop("Fixes graphical glitches.") },
 { "MK_8100550", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,"Virtua Fighter (Europe)", gettext_noop("Fixes graphical glitches.") },
 { "GS-9039", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Virtua Fighter Remix (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "MK-81023", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Virtua Fighter Remix (USA)", gettext_noop("Fixes graphical glitches.") },
 { "MK-8102350", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,"Virtua Fighter Remix (Europe)", gettext_noop("Fixes graphical glitches.") },
 { "SG-7103", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Virtua Fighter Remix (SegaNet)", gettext_noop("Fixes graphical glitches.") },
 { "T-36102G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Whizz (Japan)", gettext_noop("Fixes major graphical issues during gameplay.") },
 { "T-9515H-50", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,"Whizz (Europe)", gettext_noop("Fixes major graphical issues during gameplay.") },
 { "T-26105G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN, "Wolf Fang SS - Kuuga 2001 (Japan)", gettext_noop("Fixes graphical glitches.") },
 { "T-28004G", HORRIBLEHACK_VDP1RWDRAWSLOWDOWN,	"Yu-No (Japan)", gettext_noop("Reduces FMV tearing.") },

/*
 // Doesn't completely fix the problem.
 { "T-12519H", HORRIBLEHACK_SCUINTDELAY,	"Loaded (USA)", gettext_noop("Fixes hang at end of level.") },
 { "T-12301H", HORRIBLEHACK_SCUINTDELAY,	"Loaded (Europe)", gettext_noop("Fixes hang at end of level.") },
 { "T-12504G", HORRIBLEHACK_SCUINTDELAY,	"Blood Factory (Japan)", gettext_noop("Fixes hang at end of level.") },
*/

 // Still random hangs...wtf is this game doing...
 { "T-6006G", HORRIBLEHACK_NOSH2DMALINE106 | HORRIBLEHACK_VDP1INSTANT, "Thunderhawk II (Japan)", gettext_noop("Fixes hangs just before and during gameplay.") },
 { "T-11501H00", HORRIBLEHACK_NOSH2DMALINE106 | HORRIBLEHACK_VDP1INSTANT, "Thunderstrike II (USA)", gettext_noop("Fixes hangs just before and during gameplay.") },
};

uint32 DB_LookupHH(const char* sgid, const uint8* fd_id)
{
 for(auto& hh : hhdb)
 {
  if((hh.sgid && !strcmp(hh.sgid, sgid)) || (!hh.sgid && !memcmp(hh.fd_id, fd_id, 16)))
  {
   return hh.horrible_hacks;
  }
 }

 return 0;
}

//
//
//
//
//
//
//
//
//
static const STVGameInfo STVGI[] =
{
 // Broken(encryption)
 {
  "Astra SuperStars",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_315_5881,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "epr20825.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20827.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20828.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20829.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20830.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20831.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20826.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20832.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20833.9" },
  }
 },

 {
  "Baku Baku Animal",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr17969.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr17970.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr17971.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr17972.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr17973.5" },
  }
 },

 // Broken, needs extra sound board emulation
 {
  "Batman Forever",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0100000, STV_MAP_BYTE, "350-mpa1.u19" },
   { 0x0200001, 0x0100000, STV_MAP_BYTE, "350-mpa1.u16" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "gfx0.u1" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "gfx1.u3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "gfx2.u5" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "gfx3.u8" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "gfx4.u12" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "gfx5.u15" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "gfx6.u18" },
  }
 },

 // Broken
 {
  "Choro Q Hyper Racing 5",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22.bin", 0x4F4D6229 },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24.bin" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26.bin" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28.bin" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30.bin" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "ic32.bin" },
   { 0x0E00000, 0x0200000, STV_MAP_16LE, "ic34.bin" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "ic36.bin" },
  }
 },

 {
  "Columns '97",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr19553.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19554.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19555.3" },
  }
 },

 {
  "Cotton 2",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr20122.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20117.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20118.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20119.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20120.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20121.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20116.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20123.8" },
  }
 },

 {
  "Cotton Boomerang",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr21075.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr21070.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr21071.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr21072.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr21073.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr21074.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr21069.1" },
  }
 },

 {
  "Critter Crusher",
  SMPC_AREA_EU_PAL,
  STV_CONTROL_HAMMER,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr-18821.ic13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr-18821.ic13" },

   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr-18789.ic8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr-18788.ic9" },
  }
 },

 {
  "DaeJeon! SanJeon SuJeon",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_SANJEON,
  false,
  {
   { 0x0000001, 0x0200000, STV_MAP_BYTE, "ic11", 0x0D30DA34 },
   { 0x0400000, 0x0200000, STV_MAP_16BE, "ic13" },
   { 0x0600000, 0x0200000, STV_MAP_16BE, "ic14" },
   { 0x0800000, 0x0200000, STV_MAP_16BE, "ic15" },
   { 0x0A00000, 0x0200000, STV_MAP_16BE, "ic16" },
   { 0x0C00000, 0x0200000, STV_MAP_16BE, "ic17" },
   { 0x0E00000, 0x0200000, STV_MAP_16BE, "ic18" },
   { 0x1000000, 0x0200000, STV_MAP_16BE, "ic19" },
   { 0x1200000, 0x0200000, STV_MAP_16BE, "ic20" },
   { 0x1400000, 0x0200000, STV_MAP_16BE, "ic21" },
   { 0x1600000, 0x0200000, STV_MAP_16BE, "ic22" },
   { 0x1800000, 0x0400000, STV_MAP_16BE, "ic12" },
  }
 },

 {
  "Danchi de Hanafuda",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr21974.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr21970.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr21971.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr21972.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr21973.5" },
  }
 },

 // TODO: needs special controller remapping?
 {
  "Danchi de Quiz",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22", 0xD2CAACB5 },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "ic32" },
   { 0x0E00000, 0x0200000, STV_MAP_16LE, "ic34" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "ic36" },
   { 0x1200000, 0x0200000, STV_MAP_16LE, "ic23" },
   { 0x1400000, 0x0200000, STV_MAP_16LE, "ic25" },
  }
 },

 // Broken
 {
  "Dancing Fever Gold",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000000, 0x0080000, STV_MAP_16LE, "13" },
   { 0x0080000, 0x0080000, STV_MAP_16LE, "13" },
   { 0x0100000, 0x0080000, STV_MAP_16LE, "13" },
#if 1
   { 0x0400000, 0x0400000, STV_MAP_16LE, "2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "1" },
#else
   { 0x0400000, 0x0400000, STV_MAP_16LE, "1" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "2" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "3" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "4" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "5" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "6" },
#endif
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "11" },
   { 0x2C00000, 0x0400000, STV_MAP_16LE, "12" },
  }
 },

 // Broken(encryption+compression)
 {
  "Decathlete (V1.000)",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_315_5838,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "epr18967.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18968.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18969.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18970.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18971.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18972.6" },
  }
 },

 // Broken(encryption+compression)
 {
  "Decathlete (V1.001)",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_315_5838,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "epr18967a.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18968.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18969.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18970.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18971.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18972.6" },
  }
 },

 {
  "Die Hard Arcade",
  SMPC_AREA_NA,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr19119.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19115.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19116.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19117.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19118.5" },
  }
 },

 {
  "Dynamite Deka",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr19114.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19115.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19116.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19117.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19118.5" },
  }
 },

 {
  "Ejihon Tantei Jimusyo",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr18137.13" },
   { 0x1000001, 0x0080000, STV_MAP_BYTE,  "epr18137.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18138.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18139.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18140.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18141.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18142.6" },
  }
 },

 {
  "Final Arch",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "finlarch.13" },
   { 0x0200001, 0x0100000, STV_MAP_BYTE,  "finlarch.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18257.2" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18257.2" },

   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18258.3" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr18258.3" },

   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18259.4" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr18259.4" },

   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18260.5" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr18260.5" },
  }
 },


 {
  "Final Fight Revenge",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_315_5881,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "ffr110.ic35" },

   { 0x0200000, 0x0200000, STV_MAP_16LE, "opr21872.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr21873.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr21874.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr21875.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr21876.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr21877.6" },
   { 0x1800000, 0x0200000, STV_MAP_16LE, "opr21878.1" },
  }
 },

 {
  "Find Love",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "epr20424.13" },

   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr20431.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20426.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20427.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20428.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20429.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20430.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20425.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20432.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20433.9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr20434.10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr20435.11" },
   { 0x2C00000, 0x0400000, STV_MAP_16LE, "mpr20436.12" }
  }
 },

 {
  "Funky Head Boxers",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fr18541a.13" },
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr18538.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18533.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18534.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18535.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18536.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18537.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr18532.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr18539.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr18540.9" },
  }
 },

 {
  "Golden Axe: The Duel",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr17766.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr17766.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr17768.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr17769.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr17770.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr17771.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr17772.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr17767.1" },
  }
 },

 {
  "Groove on Fight: Gouketsuji Ichizoku 3",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0100000, STV_MAP_16LE, "mpr19820.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19815.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19816.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19817.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19818.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr19819.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr19814.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr19821.8" },
   { 0x2000000, 0x0200000, STV_MAP_16LE, "mpr19822.9" }
  }
 },

 {
  "Guardian Force",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr20844.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20839.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20840.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20841.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20842.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20843.6" },
  }
 },

 // Broken
 {
  "Hashire Patrol Car",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22.bin", 0x635EB1AF },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24.bin" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26.bin" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28.bin" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30.bin" },
  }
 },

 {
  "Karaoke Quiz Intro Don Don!",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE, "epr18937.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE, "epr18937.13" },
   { 0x0200000, 0x0100000, STV_MAP_16LE, "mpr18944.7" }, 
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18939.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18940.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18941.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18942.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18943.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr18938.1" },
  }
 },

 // Broken
 {
  "Magical Zunou Power",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "flash.ic13" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr-19354.ic2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr-19355.ic3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr-19356.ic4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr-19357.ic5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr-19358.ic6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr-19359.ic1" },
  }
 },

 {
  "Maru-Chan de Goo!",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "epr20416.13" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20417.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20418.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20419.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20420.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20421.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20422.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20423.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20443.9" }
  }
 },

 {
  "Mausuke no Ojama the World",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "ic13.bin" },
   { 0x0200001, 0x0100000, STV_MAP_BYTE, "ic13.bin" },

   { 0x0400000, 0x0200000, STV_MAP_16LE, "mcj-00.2" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "mcj-01.3" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "mcj-02.4" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "mcj-03.5" },
   { 0x1400000, 0x0200000, STV_MAP_16LE, "mcj-04.6" },
   { 0x1800000, 0x0200000, STV_MAP_16LE, "mcj-05.1" },
   { 0x1C00000, 0x0200000, STV_MAP_16LE, "mcj-06.8" },
  }
 },

 // Broken
 {
  "Microman Battle Charge",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22", 0x83523F5E },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "ic32" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "ic34" },
   { 0x1200000, 0x0200000, STV_MAP_16LE, "ic36" },
  }
 },

 // Broken
 {
  "Nerae Super Goal",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22.bin", 0xC7B1A30B },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24.bin" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26.bin" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28.bin" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30.bin" },
  }
 },

 {
  "Othello Shiyouyo",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr20967.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20963.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20964.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20965.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20966.5" },
  }
 },

 {
  "Pebble Beach: The Great Shot",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr18852.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr18852.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18853.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18854.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18855.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18856.5" },
  }
 },

 // Broken
 {
  "Pro Mahjong Kiwame S",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr18737.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr18737.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18738.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18739.3" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "mpr18740.4" },
  }
 },

 {
  "Purikura Daisakusen",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr19337.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19333.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19334.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19335.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19336.5" },
  }
 },

 {
  "Puyo Puyo Sun",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr19531.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr19531.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19533.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19534.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19535.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19536.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr19537.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr19532.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr19538.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr19539.9" },
  }
 },

 {
  "Puzzle & Action: BoMulEul Chajara",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0080000, STV_MAP_BYTE,  "2.ic13_2" },
   { 0x0200001, 0x0080000, STV_MAP_BYTE,  "1.ic13_1" },

   { 0x0400000, 0x0400000, STV_MAP_16BE, "bom210-10.ic2" },
   { 0x1C00000, 0x0400000, STV_MAP_16BE, "bom210-10.ic2" },

   { 0x0800000, 0x0400000, STV_MAP_16BE, "bom210-11.ic3" },
   { 0x2000000, 0x0400000, STV_MAP_16BE, "bom210-11.ic3" },

   { 0x0C00000, 0x0400000, STV_MAP_16BE, "bom210-12.ic4" },
   { 0x2400000, 0x0400000, STV_MAP_16BE, "bom210-12.ic4" },

   { 0x1000000, 0x0400000, STV_MAP_16BE, "bom210-13.ic5" },
   { 0x2800000, 0x0400000, STV_MAP_16BE, "bom210-13.ic5" },
  }
 },

 {
  "Puzzle & Action: Sando-R",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "sando-r.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr18635.8" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr18635.8" },

   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr18636.9" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr18636.9" },

   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18637.10" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr18637.10" },

   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18638.11" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr18638.11" },
  }
 },

 {
  "Puzzle & Action: Treasure Hunt",
  SMPC_AREA_NA,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0080000, STV_MAP_BYTE,  "th-ic7_2.stv" },
   { 0x0200001, 0x0080000, STV_MAP_BYTE,  "th-ic7_1.stv" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "th-e-2.ic2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "th-e-3.ic3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "th-e-4.ic4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "th-e-5.ic5" },
  }
 },

 // 0x0600EDBC
 {
  "Radiant Silvergun",
  SMPC_AREA_JP,
  STV_CONTROL_RSG,
  STV_EC_CHIP_RSG,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr20958.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20959.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20960.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20961.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20962.5" },
  }
 },

 {
  "Sakura Taisen: Hanagumi Taisen Columns",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0100000, STV_MAP_16LE, "mpr20143.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20138.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20139.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20140.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20141.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20142.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20137.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20144.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20145.9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr20146.10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr20147.11" },
   { 0x2C00000, 0x0400000, STV_MAP_16LE, "mpr20148.12" }
  }
 },

 {
  "Sea Bass Fishing",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "seabassf.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20551.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20552.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20553.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20554.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20555.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20550.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20556.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20557.9" },
  }
 },

 {
  "Shanghai: The Great Wall",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr18341.7" },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "mpr18340.2" },
  }
 },

 {
  "Shienryu",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  true,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr19631.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19632.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19633.3" },
  }
 },

 // Broken
 {
  "Sky Challenger",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22.bin", 0x6AE68F06 },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24.bin" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26.bin" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28.bin" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30.bin" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "ic32.bin" },
  }
 },

 // Broken
 {
  "Soreyuke Anpanman Crayon Kids",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22.bin", 0x8483A390 },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24.bin" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26.bin" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28.bin" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30.bin" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "ic32.bin" },
   { 0x0E00000, 0x0200000, STV_MAP_16LE, "ic34.bin" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "ic36.bin" },
  }
 },

 {
  "Soukyu Gurentai",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr19188.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19189.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19190.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19191.4" },
   { 0x1000000, 0x0200000, STV_MAP_16LE, "mpr19192.5" },
  }
 },

 // Broken, needs custom BIOS and CD?
 {
  "Sport Fishing 2",
  SMPC_AREA_NA,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "epr-18427.ic13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr-18273.ic2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr-18274.ic3" },
   { 0x0C00000, 0x0200000, STV_MAP_16LE, "mpr-18275.ic4" },
  }
 },

 // Broken(encryption)
 {
  "Steep Slope Sliders",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_315_5881,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr21488.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr21488.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr21489.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr21490.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr21491.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr21492.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr21493.6" },
  }
 },

 // Broken
 {
  "Stress Busters",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "epr-21300a.ic13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr-21290.ic2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr-21291.ic3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr-21292.ic4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr-21293.ic5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr-21294.ic6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr-21289.ic1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr-21296.ic8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr-21297.ic9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr-21298.ic10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr-21299.ic11" },
  }
 },

 {
  "Suiko Enbu",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr17834.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr17836.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr17837.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr17838.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr17839.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr17840.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr17835.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr17841.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr17842.9" },
  }
 },

 {
  "Super Major League",
  SMPC_AREA_NA,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr18777.13" },
   { 0x1000001, 0x0080000, STV_MAP_BYTE,  "epr18777.13" },

   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr18778.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr18779.9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr18780.10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr18781.11" },
   { 0x2C00000, 0x0200000, STV_MAP_16LE, "mpr18782.12" },
  }
 },

 {
  "Taisen Tanto-R Sashissu!!",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE, "epr20542.13" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20544.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20545.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20546.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20547.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20548.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20543.1" },
  }
 },

 {
  "Tatacot",
  SMPC_AREA_JP,
  STV_CONTROL_HAMMER,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr-18790.ic13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr-18790.ic13" },

   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr-18789.ic8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr-18788.ic9" },
  }
 },


 // Broken
 {
  "Technical Bowling",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "ic22", 0xD426412C },
   { 0x0400000, 0x0200000, STV_MAP_16LE, "ic24" },
   { 0x0600000, 0x0200000, STV_MAP_16LE, "ic26" },
   { 0x0800000, 0x0200000, STV_MAP_16LE, "ic28" },
   { 0x0A00000, 0x0200000, STV_MAP_16LE, "ic30" },
  }
 },

 // Broken(encryption)
 {
  "Tecmo World Cup '98",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_315_5881,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "epr20819.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20821.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20822.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20823.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20824.5" },
  }
 },

 // Broken(encryption)
 {
  "Touryuu Densetsu Elan Doree",
  SMPC_AREA_JP,
  STV_CONTROL_6B,
  STV_EC_CHIP_315_5881,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr21307.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr21301.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr21302.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr21303.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr21304.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr21305.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr21306.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr21308.8" },
  }
 },

 {
  "Virtua Fighter Kids",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr18914.13" },

   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr18916.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr18917.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr18918.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr18915.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr18919.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr18920.9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr18921.10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr18922.11" },
   { 0x2C00000, 0x0400000, STV_MAP_16LE, "mpr18923.12" },
  }
 },

 {
  "Virtua Fighter Remix",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0080000, STV_MAP_BYTE,  "epr17944.13" },
   { 0x0100001, 0x0080000, STV_MAP_BYTE,  "epr17944.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr17946.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr17947.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr17948.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr17949.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr17950.6" },
   { 0x1800000, 0x0200000, STV_MAP_16LE, "mpr17945.1" }
  }
 },

 // Broken(needs special controller)
 {
  "Virtual Mahjong",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr19620.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr19615.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr19616.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr19617.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr19618.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr19619.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr19614.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr19621.8" },
  }
 },

 // Broken(needs special controller)
 {
  "Virtual Mahjong 2: My Fair Lady",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0200000, 0x0200000, STV_MAP_16LE, "mpr21000.7" },
   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20995.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20996.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20997.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20998.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20999.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20994.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr21001.8" },
  }
 },

 {
  "Winter Heat",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "fpr20108.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20110.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20111.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20112.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20113.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20114.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20109.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20115.8" },
  }
 },

 // Broken
 {
  "Yatterman Plus",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   //{ 0x0000000, 0x0080000, STV_MAP_16LE,  "epr-21122.ic13" },
   //{ 0x0080000, 0x0080000, STV_MAP_16LE,  "epr-21122.ic13" },
   //{ 0x0080001, 0x0020000, STV_MAP_BYTE,   "epr-21121.bin" },
   //{ 0x0030001, 0x0020000, STV_MAP_BYTE,   "epr-21121.bin" },
   { 0x0200000, 0x0080000, STV_MAP_16LE,  "epr-21122.ic13" },
   { 0x0280000, 0x0080000, STV_MAP_16LE,  "epr-21122.ic13" },


   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr-21125.ic02" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr-21130.ic03" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr-21126.ic04" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr-21131.ic05" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr-21127.ic06" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr-21132.ic07" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr-21128.ic08" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr-21133.ic09" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr-21129.ic10" },
   { 0x2800000, 0x0400000, STV_MAP_16LE, "mpr-21124.ic11" },
   { 0x2C00000, 0x0400000, STV_MAP_16LE, "mpr-21123.ic12" },
  }
 },

 {
  "Zen Nippon Pro-Wrestling Featuring Virtua",
  SMPC_AREA_JP,
  STV_CONTROL_3B,
  STV_EC_CHIP_NONE,
  STV_ROMTWIDDLE_NONE,
  false,
  {
   { 0x0000001, 0x0100000, STV_MAP_BYTE,  "epr20398.13" },

   { 0x0400000, 0x0400000, STV_MAP_16LE, "mpr20400.2" },
   { 0x0800000, 0x0400000, STV_MAP_16LE, "mpr20401.3" },
   { 0x0C00000, 0x0400000, STV_MAP_16LE, "mpr20402.4" },
   { 0x1000000, 0x0400000, STV_MAP_16LE, "mpr20403.5" },
   { 0x1400000, 0x0400000, STV_MAP_16LE, "mpr20404.6" },
   { 0x1800000, 0x0400000, STV_MAP_16LE, "mpr20399.1" },
   { 0x1C00000, 0x0400000, STV_MAP_16LE, "mpr20405.8" },
   { 0x2000000, 0x0400000, STV_MAP_16LE, "mpr20406.9" },
   { 0x2400000, 0x0400000, STV_MAP_16LE, "mpr20407.10" },
  }
 },
};

const STVGameInfo* DB_LookupSTV(const std::string& fname, Stream* s)
{
 uint8 tmp[0x80];
 uint32 dr;
 uint32 head_crc32;

 dr = s->read(tmp, sizeof(tmp), false);

 s->rewind();

 head_crc32 = crc32_zip(0, tmp, dr);

 //printf("%s 0x%08X\n", fname.c_str(), head_crc32);

 for(const STVGameInfo& e : STVGI)
 {
  auto const& rle = e.rom_layout[0];

  if(!MDFN_strazicmp(fname, rle.fname))
  {
   if(!rle.head_crc32 || head_crc32 == rle.head_crc32)
    return &e;
  }
 }

 return nullptr;
}

static std::string FDIDToString(const uint8 (&fd_id)[16])
{
 return MDFN_sprintf("%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x", fd_id[0], fd_id[1], fd_id[2], fd_id[3], fd_id[4], fd_id[5], fd_id[6], fd_id[7], fd_id[8], fd_id[9], fd_id[10], fd_id[11], fd_id[12], fd_id[13], fd_id[14], fd_id[15]);
}

std::string DB_GetHHDescriptions(const uint32 hhv)
{
 std::string sv;

 if(hhv & HORRIBLEHACK_NOSH2DMALINE106)
  sv += "Block SH-2 DMA on last line of frame. ";

 if(hhv & HORRIBLEHACK_NOSH2DMAPENALTY)
  sv += "Disable slowing down of SH-2 CPU reads/writes during SH-2 DMA. ";

 if(hhv & HORRIBLEHACK_VDP1VRAM5000FIX)
  sv += "Patch VDP1 VRAM to break an infinite loop. ";

 if(hhv & HORRIBLEHACK_VDP1RWDRAWSLOWDOWN)
  sv += "SH-2 reads/writes from/to VDP1 slow down command execution. ";

 if(hhv & HORRIBLEHACK_VDP1INSTANT)
  sv += "Execute VDP1 commands instantly. ";

/*
 if(hhv & HORRIBLEHACK_SCUINTDELAY)
  sv += "Delay SCU interrupt generation after a write to SCU IMS unmasks a pending interrupt. ";
*/

 return sv;
}

void DB_GetInternalDB(std::vector<GameDB_Database>* databases)
{
 databases->push_back({
	"region",
	gettext_noop("Region"),
	gettext_noop("This database is used in conjunction with a game's internal header and the \"\5ss.region_default\" setting to automatically select the region of Saturn to emulate when the \"\5ss.region_autodetect\" setting is set to \"1\", the default.")
	});

 for(auto& re : regiondb)
 {
  const char* sv = nullptr;

  switch(re.area)
  {
   default: assert(0); break;
   case SMPC_AREA_JP: sv = _("Japan"); break;
   case SMPC_AREA_ASIA_NTSC: sv = _("Asia NTSC"); break;
   case SMPC_AREA_NA: sv = _("North America"); break;
   case SMPC_AREA_CSA_NTSC: sv = _("Brazil"); break;
   case SMPC_AREA_KR: sv = _("South Korea"); break;
   case SMPC_AREA_ASIA_PAL: sv = _("Asia PAL"); break;
   case SMPC_AREA_EU_PAL: sv = _("Europe"); break;
  }
  //
  //
  GameDB_Entry e;

  e.GameID = FDIDToString(re.id);
  e.GameIDIsHash = true;
  e.Name = re.game_name;
  e.Setting = sv;
  e.Purpose = ""; //ca.purpose ? _(ca.purpose) : "";

  databases->back().Entries.push_back(e);
 }
 //
 //
 //
 databases->push_back({
	"cart",
	gettext_noop("Cart"),
	gettext_noop("This database is used to automatically select the type of cart to emulate when the \"\5ss.cart\" setting is set to \"auto\", the default.  If a game is not found in the database when auto selection is enabled, then the cart used is specified by the \"\5ss.cart.auto_default\" setting, default \"backup\"(a backup memory cart).")
	});

 for(auto& ca : cartdb)
 {
  const char* sv = nullptr;

  switch(ca.cart_type)
  {
   default: assert(0); break;
   case CART_NONE: sv = "None"; break;
   case CART_BACKUP_MEM: sv = "Backup Memory"; break;
   case CART_EXTRAM_1M: sv = "1MiB Extended RAM"; break;
   case CART_EXTRAM_4M: sv = "4MiB Extended RAM"; break;
   case CART_KOF95: sv = "King of Fighters 95 ROM"; break;
   case CART_ULTRAMAN: sv = "Ultraman ROM"; break;
   case CART_NLMODEM: sv = "Netlink Modem"; break;
   case CART_CS1RAM_16M: sv = "16MiB A-bus CS1 RAM"; break;
  }
  //
  //
  GameDB_Entry e;

  if(ca.sgid)
  {
   unsigned lfcount = 0;

   e.GameIDIsHash = false;
   e.GameID = ca.sgid;

   if(ca.sgname)
   {
    for(; lfcount < 1; lfcount++)
     e.GameID += '\n';
    e.GameID += ca.sgname;
   }
  }
  else
  {
   e.GameIDIsHash = true;
   e.GameID = FDIDToString(ca.fd_id);
  }

  e.Name = ca.game_name;
  e.Setting = sv;
  e.Purpose = ca.purpose ? _(ca.purpose) : "";

  databases->back().Entries.push_back(e);
 }
 //
 //
 //
 databases->push_back({
	"cachemode",
	gettext_noop("Cache Mode"),
	gettext_noop("This database is used to automatically select cache emulation mode, to fix various logic and timing issues in games.  The default cache mode is data-only(with no high-level bypass).\n\nThe cache mode \"Data-only, with high-level bypass\" is a hack of sorts, to work around cache coherency bugs in games.  These bugs are typically masked on a real Saturn due to the effects of instruction fetches on the cache, but become a problem when only data caching is emulated.\n\nFull cache emulation is not enabled globally primarily due to the large increase in host CPU usage.\n\nFor ST-V games, this database is not used, and instead full cache emulation is always enabled.")
	});
 for(auto& c : cemdb)
 {
  const char* sv = nullptr;

  switch(c.mode)
  {
   default: assert(0); break;
   case CPUCACHE_EMUMODE_DATA_CB: sv = _("Data only, with high-level bypass"); break;
   case CPUCACHE_EMUMODE_FULL: sv = _("Full"); break;
  }
  GameDB_Entry e;

  if(c.sgid)
  {
   unsigned lfcount = 0;

   e.GameIDIsHash = false;
   e.GameID = c.sgid;

   if(c.sgname)
   {
    for(; lfcount < 1; lfcount++)
     e.GameID += '\n';
    e.GameID += c.sgname;
   }

   if(c.sgarea)
   {
    for(; lfcount < 2; lfcount++)
     e.GameID += '\n';
    e.GameID += c.sgarea;
   }
  }
  else
  {
   e.GameIDIsHash = true;
   e.GameID = FDIDToString(c.fd_id);
  }
  e.Name = c.game_name;
  e.Setting = sv;
  e.Purpose = c.purpose ? _(c.purpose) : "";

  databases->back().Entries.push_back(e);
 }
 //
 //
 //
 databases->push_back({
	"horriblehacks",
	gettext_noop("Horrible Hacks"),
	gettext_noop("This database is used to automatically enable various horrible hacks to fix issues in certain games.\n\nNote that slowing down VDP1 command execution due to SH-2 reads/writes isn't a horrible hack per-se, but it's activated on a per-game basis to avoid the likelihood of breaking some games due to overall Saturn emulation timing inaccuracies.\n\nFor ST-V games, this database is not used, and instead VDP1 command slowdown on SH-2 reads/writes is always enabled.")
	});
 for(auto& hh : hhdb)
 {
  std::string sv = DB_GetHHDescriptions(hh.horrible_hacks);
  GameDB_Entry e;

  e.GameID = hh.sgid ? hh.sgid : FDIDToString(hh.fd_id);
  e.GameIDIsHash = !hh.sgid;
  e.Name = hh.game_name;
  e.Setting = sv;
  e.Purpose = hh.purpose ? _(hh.purpose) : "";

  databases->back().Entries.push_back(e);
 }
}

}
