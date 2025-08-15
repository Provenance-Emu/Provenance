/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAccess_CHD.h:                                                            */
/*   CHD-backed CD access using libchdr                                        */
/*                                                                            */
/*   Copyright (C) 2025 Provenance Team                                       */
/*   Based on Mednafen's CDAccess interface                                   */
/******************************************************************************/

#ifndef __MDFN_CDROM_CDACCESS_CHD_H
#define __MDFN_CDROM_CDACCESS_CHD_H

#include <mednafen/mednafen.h>
#include "CDAccess.h"
#include "CDUtility.h"

// libchdr
#include <libchdr/chd.h>
#include <libchdr/cdrom.h>

#include <vector>
#include <string>

namespace Mednafen
{

class CDAccess_CHD final : public CDAccess
{
public:
  CDAccess_CHD(VirtualFS* vfs, const std::string& path, bool image_memcache);
  ~CDAccess_CHD() override;

  void Read_Raw_Sector(uint8* buf, int32 lba) override;
  bool Fast_Read_Raw_PW_TSRE(uint8* pwbuf, int32 lba) const noexcept override;
  void Read_TOC(CDUtility::TOC* out_toc) override;

private:
  // Helpers
  void parse_toc_from_metadata();
  void ensure_hunk_loaded(uint32 hunk_index) const;

  // Map TYPE/SUBTYPE strings from CHD metadata
  static void map_type_strings(const char* type_str, const char* subtype_str, uint8& control_out);

  // State
  chd_file* chd = nullptr;
  mutable std::vector<uint8> hunk_buf;  // mutable for caching in const methods if needed
  mutable int64 cached_hunk_index = -1;

  uint32 bytes_per_hunk = 0;
  uint32 bytes_per_frame = 0;  // 2352 or 2448 typically
  bool   subcode_included = false; // true if bytes_per_frame >= 2448

  int32 total_frames = 0;   // total sectors/frames

  CDUtility::TOC toc;       // parsed TOC
};

}

#endif
