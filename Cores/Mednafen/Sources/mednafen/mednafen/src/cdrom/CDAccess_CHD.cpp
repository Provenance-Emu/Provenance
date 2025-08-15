/* Mednafen - CHD-backed CD access (libchdr) */

#include <mednafen/mednafen.h>
#include <mednafen/general.h>

#include <cstdio>
#include <cstring>
#include <strings.h>
#include <string>
#include <vector>
#include <algorithm>

#include "CDAccess_CHD.h"

namespace Mednafen {

using namespace CDUtility;

// Synthesize Q-subchannel (ADR_CURPOS) for program area (lba >= 0, before leadout).
// - Properly sets track number and index (01 for program area)
// - Computes track-relative and absolute MSF
// - Interleaves into 96 bytes (Q only; other subchannels zero, high bit set)
static void synth_program_qpw(const TOC& toc, const int32 lba, uint8* SubPWBuf)
{
  uint8 q[0xC];
  memset(q, 0, sizeof(q));

  // Determine current track by LBA.
  int trk = toc.FindTrackByLBA((uint32)lba);
  if(trk <= 0) trk = toc.first_track ? toc.first_track : 1;

  const uint32 track_start_lba = toc.tracks[trk].lba;
  const uint32 rel_lba = (lba >= (int32)track_start_lba) ? (uint32)(lba - (int32)track_start_lba) : 0u;

  uint32 rm, rs, rf;
  uint32 am, as, af;

  rf = (rel_lba % 75);
  rs = ((rel_lba / 75) % 60);
  rm = (rel_lba / 75 / 60);

  af = ((lba + 150) % 75);
  as = (((lba + 150) / 75) % 60);
  am = (((lba + 150) / 75 / 60));

  const uint8 adr = ADR_CURPOS;
  const uint8 control = toc.tracks[trk].valid ? toc.tracks[trk].control : 0x0;

  q[0] = (adr << 0) | (control << 4);
  q[1] = U8_to_BCD((uint8)trk);
  q[2] = U8_to_BCD(0x01); // Index 1 in program area

  // Track-relative MSF
  q[3] = U8_to_BCD((uint8)rm);
  q[4] = U8_to_BCD((uint8)rs);
  q[5] = U8_to_BCD((uint8)rf);

  q[6] = 0x00; // Zero

  // Absolute MSF
  q[7] = U8_to_BCD((uint8)am);
  q[8] = U8_to_BCD((uint8)as);
  q[9] = U8_to_BCD((uint8)af);

  subq_generate_checksum(q);

  // Interleave Q into PW (Q at bit 6, high bit set; others zero)
  for(int i = 0; i < 96; i++)
    SubPWBuf[i] = (((q[i >> 3] >> (7 - (i & 0x7))) & 1) ? 0x40 : 0x00) | 0x80;
}

static inline bool qpw_is_valid_curpos(const uint8* pw)
{
  uint8 qbuf[12];
  subq_deinterleave(pw, qbuf);
  return subq_check_checksum(qbuf) && ((qbuf[0] & 0xF) == ADR_CURPOS);
}

static inline uint32 div_floor(uint32 a, uint32 b) { return a / b; }
static inline uint32 mod(uint32 a, uint32 b) { return a % b; }

CDAccess_CHD::CDAccess_CHD(VirtualFS* vfs, const std::string& path, bool /*image_memcache*/)
{
  toc.Clear();

  // Try to open CHD by OS path
  // NOTE: VirtualFS::get_human_path() is for display/logging and adds quotes.
  // Passing that to libchdr will result in a quoted path that fails to open.
  // Use the raw path here.
  std::string os_path = path;

  chd_error err = chd_open(os_path.c_str(), CHD_OPEN_READ, nullptr, &chd);
  if (err != CHDERR_NONE || !chd)
  {
    throw MDFN_Error(0, _("Failed to open CHD '%s': %s"), os_path.c_str(), chd_error_string(err));
  }

  const chd_header* hd = chd_get_header(chd);
  if (!hd)
  {
    chd_close(chd);
    chd = nullptr;
    throw MDFN_Error(0, _("chd_get_header() failed for '%s'"), os_path.c_str());
  }

  bytes_per_hunk = hd->hunkbytes;  // decompressed bytes per hunk

  // Derive bytes_per_frame and frames_per_hunk from the header. CD frames are
  // always 2352 (no subcode) or 2448 (with raw 96B subcode appended).
  if ((bytes_per_hunk % 2448) == 0)
  {
    bytes_per_frame = 2448;
    frames_per_hunk = bytes_per_hunk / 2448;
    subcode_included = true;
  }
  else if ((bytes_per_hunk % 2352) == 0)
  {
    bytes_per_frame = 2352;
    frames_per_hunk = bytes_per_hunk / 2352;
    subcode_included = false;
  }
  else
  {
    // Fallback: assume single-frame hunks with no subcode
    bytes_per_frame = bytes_per_hunk;
    frames_per_hunk = 1;
    subcode_included = (bytes_per_frame >= 2448);
  }

  // Compute total frames from logicalbytes when available; if not, fall back to totalhunks
  uint64 logicalbytes = 0;
#if CHD_HEADER_VERSION >= 3
  logicalbytes = hd->logicalbytes;
#endif
  if (logicalbytes)
    total_frames = (int32)(logicalbytes / bytes_per_frame);
  else
    total_frames = (int32)((uint64)hd->totalhunks * frames_per_hunk);

  hunk_buf.resize(bytes_per_hunk);

  parse_toc_from_metadata();
}

CDAccess_CHD::~CDAccess_CHD()
{
  if (chd)
  {
    chd_close(chd);
    chd = nullptr;
  }
}

void CDAccess_CHD::map_type_strings(const char* type_str, const char* subtype_str, uint8& control_out)
{
  (void)subtype_str;
  // Default control flags
  control_out = 0;

  if (!type_str)
    return;

  // Data vs Audio
  // Any TYPE other than AUDIO is considered a data track
  if (strcasecmp(type_str, "AUDIO") != 0)
  {
    control_out |= SUBQ_CTRLF_DATA;
  }
}

void CDAccess_CHD::parse_toc_from_metadata()
{
  toc.Clear();

  // Iterate track metadata entries
  char meta[256];
  uint32 index = 0;
  int32 current_lba = 0;
  int min_track = 99;
  int max_track = 1;
  bool any_mode2 = false;

  while (true)
  {
    chd_error err = chd_get_metadata(chd, CDROM_TRACK_METADATA_TAG, index, meta, sizeof(meta), nullptr, nullptr, nullptr);
    if (err != CHDERR_NONE)
      break;

    // Parse formats (prefer extended format with pregap/postgap when present)
    int trackno = 0, frames = 0, pregap = 0, postgap = 0;
    char type[32] = {0}, subtype[32] = {0};

    int n = sscanf(meta, "TRACK:%d TYPE:%31s SUBTYPE:%31s FRAMES:%d PREGAP:%d %*s %*s POSTGAP:%d",
                   &trackno, type, subtype, &frames, &pregap, &postgap);
    if (n < 4)
    {
      // Try short format
      n = sscanf(meta, "TRACK:%d TYPE:%31s SUBTYPE:%31s FRAMES:%d", &trackno, type, subtype, &frames);
      pregap = 0;
      postgap = 0;
    }

    if (n >= 4 && trackno >= 1 && trackno <= 99)
    {
      // Track start LBA is at current_lba; pregap occupies negative LBAs
      toc.tracks[trackno].lba = current_lba;
      toc.tracks[trackno].adr = ADR_CURPOS;

      uint8 ctrl = 0;
      map_type_strings(type, subtype, ctrl);
      toc.tracks[trackno].control = ctrl;
      toc.tracks[trackno].valid = true;

      // Track string check for MODE2 to set disc_type later (best-effort)
      if (strcasestr(type, "MODE2") != nullptr)
        any_mode2 = true;

      min_track = std::min(min_track, trackno);
      max_track = std::max(max_track, trackno);

      // Advance through track data and any postgap
      current_lba += frames + postgap;
    }

    index++;
  }

  if (min_track == 99 && max_track == 1)
  {
    // No track metadata; assume a single data track starting at 0
    toc.first_track = 1;
    toc.last_track = 1;
    toc.tracks[1].lba = 0;
    toc.tracks[1].adr = ADR_CURPOS;
    toc.tracks[1].control = SUBQ_CTRLF_DATA;
    toc.tracks[1].valid = true;
    // total_frames is left as computed from header
  }
  else
  {
    toc.first_track = (uint8)std::max(1, min_track);
    toc.last_track = (uint8)std::min(99, max_track);
    // Compute total frames from parsed metadata
    total_frames = current_lba;
  }

  toc.disc_type = any_mode2 ? DISC_TYPE_CD_XA : DISC_TYPE_CDDA_OR_M1;

  // Ensure leadout is set based on total_frames
  if (!toc.tracks[100].valid) {
    toc.tracks[100].lba = total_frames;
    toc.tracks[100].adr = ADR_CURPOS;
    toc.tracks[100].control = (toc.last_track ? toc.tracks[toc.last_track].control : 0);
    toc.tracks[100].valid = true;
  }
}

void CDAccess_CHD::ensure_hunk_loaded(uint32 hunk_index) const
{
  if ((int64)hunk_index == cached_hunk_index)
    return;

  chd_error err = chd_read(chd, hunk_index, hunk_buf.data());
  if (err != CHDERR_NONE)
  {
    throw MDFN_Error(0, _("chd_read() failed at hunk %u: %s"), hunk_index, chd_error_string(err));
  }

  cached_hunk_index = (int64)hunk_index;
}

void CDAccess_CHD::Read_Raw_Sector(uint8* buf, int32 lba)
{
  if (lba >= total_frames)
  {
    // Leadout synthesis
    uint8 data_synth_mode = (toc.disc_type == DISC_TYPE_CD_XA) ? 0x02 : 0x01;
    synth_leadout_sector_lba(data_synth_mode, toc, lba, buf);
    return;
  }

  if (lba < 0)
  {
    // Pre-pause synthesis
    uint8 data_synth_mode = (toc.disc_type == DISC_TYPE_CD_XA) ? 0x02 : 0x01;
    synth_udapp_sector_lba(data_synth_mode, toc, lba, 0, buf);
    return;
  }

  // Normal read from CHD
  const uint32 hunk_index = div_floor((uint32)lba, frames_per_hunk);
  const uint32 frame_in_hunk = mod((uint32)lba, frames_per_hunk);

  ensure_hunk_loaded(hunk_index);

  const uint8* src = &hunk_buf[frame_in_hunk * bytes_per_frame];

  // Always provide 2352 bytes of sector data
  memcpy(buf, src, 2352);

  if (subcode_included)
  {
    // Copy raw PW, but validate; if invalid, synthesize sensible program-area Q.
    memcpy(buf + 2352, src + 2352, 96);
    if(!qpw_is_valid_curpos(buf + 2352))
      synth_program_qpw(toc, lba, buf + 2352);
  }
  else
  {
    // CHD lacks subcode: synthesize program-area Q for normal LBAs.
    synth_program_qpw(toc, lba, buf + 2352);
  }
}

bool CDAccess_CHD::Fast_Read_Raw_PW_TSRE(uint8* pwbuf, int32 lba) const noexcept
{
  if (lba >= total_frames)
  {
    subpw_synth_leadout_lba(toc, lba, pwbuf);
    return true;
  }

  if (lba < 0)
  {
    // Pre-pause
    subpw_synth_udapp_lba(toc, lba, 0, pwbuf);
    return true;
  }

  if (subcode_included)
  {
    // Embedded subcode prevents fast re-entrant read
    return false;
  }

  // We can synthesize quickly
  subpw_synth_udapp_lba(toc, lba, 0, pwbuf);
  return true;
}

void CDAccess_CHD::Read_TOC(CDUtility::TOC* out_toc)
{
  *out_toc = toc;
}

} // namespace Mednafen
