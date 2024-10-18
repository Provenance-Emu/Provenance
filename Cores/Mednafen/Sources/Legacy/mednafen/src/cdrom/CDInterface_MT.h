/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDInterface_MT.h - Multithreaded CD Reading Interface
**  Copyright (C) 2009-2018 Mednafen Team
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

#ifndef __MDFN_CDROM_CDINTERFACE_MT_H
#define __MDFN_CDROM_CDINTERFACE_MT_H

#include <mednafen/cdrom/CDInterface.h>
#include <mednafen/cdrom/CDAccess.h>
#include <mednafen/MThreading.h>
#include <queue>

namespace Mednafen
{

// TODO: prohibit copy constructor
class CDInterface_MT : public CDInterface
{
 public:

 CDInterface_MT(std::unique_ptr<CDAccess> cda, const uint64 affinity) MDFN_COLD;
 virtual ~CDInterface_MT() MDFN_COLD;

 virtual void HintReadSector(int32 lba) override;
 virtual bool ReadRawSector(uint8 *buf, int32 lba) override;
 virtual bool ReadRawSectorPWOnly(uint8* pwbuf, int32 lba, bool hint_fullread) override;

 // FIXME: Semi-private:
 int ReadThreadStart(void);

 private:

 void Cleanup(void) MDFN_COLD;

 std::unique_ptr<CDAccess> disc_cdaccess;

 MThreading::Thread* CDReadThread;

 enum
 {
  // Status/Error messages
  CDInterface_MSG_DONE = 0,		// Read -> emu. args: No args.
  CDInterface_MSG_INFO,			// Read -> emu. args: str_message
  CDInterface_MSG_FATAL_ERROR,		// Read -> emu. args: *TODO ARGS*

  //
  // Command messages.
  //
  CDInterface_MSG_DIEDIEDIE,		// Emu -> read

  CDInterface_MSG_READ_SECTOR,		/* Emu -> read
					args[0] = lba
				*/
 };

 class CDInterface_Message
 {
  public:

  CDInterface_Message();
  CDInterface_Message(unsigned int message_, uint32 arg0 = 0, uint32 arg1 = 0, uint32 arg2 = 0, uint32 arg3 = 0);
  CDInterface_Message(unsigned int message_, const std::string &str);
  ~CDInterface_Message();

  unsigned int message;
  uint32 args[4];
  void *parg;
  std::string str_message;
 };

 class CDInterface_Queue
 {
  public:

  CDInterface_Queue();
  ~CDInterface_Queue();

  bool Read(CDInterface_Message *message, bool blocking = true);

  void Write(const CDInterface_Message &message);

  private:
  std::queue<CDInterface_Message> ze_queue;
  MThreading::Mutex *ze_mutex;
  MThreading::Cond *ze_cond;
 };

 // Queue for messages to the read thread.
 CDInterface_Queue ReadThreadQueue;

 // Queue for messages to the emu thread.
 CDInterface_Queue EmuThreadQueue;

 enum { SBSize = 256 };
 struct CDInterface_Sector_Buffer
 {
  bool valid;
  bool error;
  int32 lba;
  uint8 data[2352 + 96];
 } SectorBuffers[SBSize];

 uint32 SBWritePos;
 
 MThreading::Mutex* SBMutex;
 MThreading::Cond* SBCond;

 //
 // Read-thread-only:
 //
 int32 ra_lba;
 int32 ra_count;
 int32 last_read_lba;
};

}
#endif
