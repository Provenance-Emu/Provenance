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
  uint32 frames_per_hunk = 0;  // derived from header: hunkbytes / unitbytes
  bool   subcode_included = false; // true if bytes_per_frame >= 2448

  int32 total_frames = 0;   // total sectors/frames

  CDUtility::TOC toc;       // parsed TOC

  // Per-track mapping derived from CHD metadata (frame-based, not bytes)
  struct TrackMap
  {
    int32 lba = 0;          // logical start LBA of the track
    int32 sectors = 0;      // number of logical sectors in the track (excludes pregap_dv)
    int32 file_offset = 0;  // CHD frame index where this track's index 00/01 data begins
    uint8 control = 0;      // SUBQ control flags
    bool  audio_msb_first = false; // true for AUDIO tracks (16-bit big-endian samples)
    uint8 di_format = 0;    // simplified: 0 = AUDIO, 1 = DATA
    int32 pregap = 0;       // fixed pregap contributing to LBA (e.g., 150 for track 1)
    int32 pregap_dv = 0;    // variable pregap present only in file layout
    int32 postgap = 0;      // postgap sectors present only in file layout
  };

  TrackMap track_map[101]; // 1..99, 100 leadout copy
};

}

#endif
