/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* disk2.h:
**  Copyright (C) 2018-2023 Mednafen Team
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

#ifndef __MDFN_APPLE2_DISK2_H
#define __MDFN_APPLE2_DISK2_H

#include <mednafen/hash/sha256.h>
#include <mednafen/SimpleBitset.h>

namespace MDFN_IEN_APPLE2
{
namespace Disk2
{
//
//

enum : unsigned { num_tracks = 160 };
//enum : unsigned { samples_per_track = 1431818 };
enum : unsigned { min_bits_per_track = 46000 };
enum : unsigned { max_bits_per_track = 56048 };

struct FloppyDisk
{
 bool write_protect = false;

 struct Track
 {
  SimpleBitset<65536> data;
  uint32 length = 51024;
  bool flux_fudge = false;
 } tracks[num_tracks];

 uint32 angle = 0;	// when disk is inserted into a drive, >>3 for index into tracks[track].data; otherwise, full 32-bit representation of angle
 bool dirty = false;	// Disk has been modified(change of write protect, or track data) since last save.
 bool ever_modified = false;	// Disk has ever been modified(as compared to source disk image).
};

NO_INLINE MDFN_HOT void Tick2M(void);
void EndTimePeriod(void);
void Reset(void);
void Power(void);
void SetSeqROM(const uint8* src);
void SetBootROM(const uint8* src);
void Init(void);
void LoadDisk(Stream* sp, const std::string& ext, FloppyDisk* disk);
void HashDisk(sha256_hasher* h, const FloppyDisk* disk);
void SaveDisk(Stream* sp, const FloppyDisk* disk);
bool DetectDOS32(FloppyDisk* disk);
bool GetEverModified(FloppyDisk* disk);
void SetEverModified(FloppyDisk* disk);
MDFN_NOWARN_UNUSED bool GetClearDiskDirty(FloppyDisk* disk);
void SetDisk(unsigned drive_index, FloppyDisk* disk);
void StateAction(StateMem* sm, const unsigned load, const bool data_only);
void StateAction_Disk(StateMem* sm, const unsigned load, const bool data_only, FloppyDisk* disk, const char* sname);
void StateAction_PostLoad(const unsigned load); // Call after StateAction() and StateAction_Disk(), when loading a state.
void Kill(void);

enum
{
 GSREG_STEPPHASE = 0,
 GSREG_MOTORON,
 GSREG_DRIVESEL,
 GSREG_MODE
};

uint32 GetRegister(const unsigned id, char* const special = nullptr, const uint32 special_len = 0);
void SetRegister(const unsigned id, const uint32 value);

//
//
}
}
#endif
