/* Mednafen - CHD-backed CD access (libchdr) */

#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/cdrom/CDUtility.h>

#include <cstdio>
#include <cstring>
#include <strings.h>
#include <string>
#include <vector>
#include <algorithm>

#include "CDAccess_CHD.h"

namespace Mednafen {

using namespace CDUtility;

// Debug logging helper (compile-time gated)
#ifndef CHD_DEBUG
#define CHD_DEBUG 0
#endif

#if CHD_DEBUG
 #define CHD_DLOG(...) MDFN_printf(__VA_ARGS__)
#else
 #define CHD_DLOG(...) do {} while(0)
#endif

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

  // Interleave Q into PW (Q at bit 6; P cleared in program area)
  for(int i = 0; i < 96; i++)
    SubPWBuf[i] = (((q[i >> 3] >> (7 - (i & 0x7))) & 1) ? 0x40 : 0x00);
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
  // Prefer unitbytes from header when available (matches Beetle-PSX mapping)
#if CHD_HEADER_VERSION >= 3
  if (hd->unitbytes == 2352 || hd->unitbytes == 2448)
  {
    bytes_per_frame = hd->unitbytes;
    frames_per_hunk = bytes_per_hunk / bytes_per_frame;
    subcode_included = (bytes_per_frame >= 2448);
  }
  else
#endif
  {
    // Derive bytes_per_frame and frames_per_hunk from hunkbytes if unitbytes not present
    // CD frames are typically 2352 (no subcode) or 2448 (with raw 96B subcode appended).
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
      chd_close(chd);
      chd = nullptr;
      throw MDFN_Error(0, _("Unsupported CHD layout: unitbytes=%u hunkbytes=%u not compatible with 2352/2448"), (unsigned)hd->unitbytes, (unsigned)bytes_per_hunk);
    }
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

  // Debug summary
  CHD_DLOG("CHD: bytes_per_frame=%u frames_per_hunk=%u subcode_included=%d total_frames=%d\n",
           (unsigned)bytes_per_frame, (unsigned)frames_per_hunk, (int)subcode_included, (int)total_frames);
  for (int t = toc.first_track; t <= toc.last_track; t++)
  {
    const TrackMap& tm = track_map[t];
    CHD_DLOG("CHD: T%02d lba=%d sectors=%d file_off=%d ctrl=0x%02x pregap=%d dv=%d postgap=%d\n",
             t, (int)tm.lba, (int)tm.sectors, (int)tm.file_offset, (unsigned)tm.control,
             (int)tm.pregap, (int)tm.pregap_dv, (int)tm.postgap);
  }
  CHD_DLOG("CHD: leadout lba=%d\n", (int)toc.tracks[100].lba);
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

  // Iterate track metadata entries, computing per-track file offsets like Beetle
  char meta[256];
  uint32 index = 0;
  int min_track = 99;
  int max_track = 1;
  bool any_mode2 = false;

  int32 plba = -150;            // running logical LBA
  int32 file_offset = 0;        // running CHD frame index
  int32 computed_total = 0;     // total sectors for leadout

  while (true)
  {
    chd_error err;
    int trackno = 0, frames = 0, pregap = 0, postgap = 0;
    char type[64] = {0}, subtype[32] = {0}, pgtype[32] = {0}, pgsub[32] = {0};

    // Prefer extended metadata2 with pregap/postgap types
    err = chd_get_metadata(chd, CDROM_TRACK_METADATA2_TAG, index, meta, sizeof(meta), nullptr, nullptr, nullptr);
    if (err == CHDERR_NONE)
    {
      if (sscanf(meta, CDROM_TRACK_METADATA2_FORMAT, &trackno, type, subtype, &frames, &pregap, pgtype, pgsub, &postgap) < 4)
        break;
    }
    else
    {
      err = chd_get_metadata(chd, CDROM_TRACK_METADATA_TAG, index, meta, sizeof(meta), nullptr, nullptr, nullptr);
      if (err != CHDERR_NONE)
        break;
      if (sscanf(meta, CDROM_TRACK_METADATA_FORMAT, &trackno, type, subtype, &frames) < 4)
        break;
      pregap = 0;
      postgap = 0;
      pgtype[0] = '\0';
      pgsub[0] = '\0';
    }

    if (trackno < 1 || trackno > 99)
    {
      index++;
      continue;
    }

    // Map control and type
    uint8 ctrl = 0;
    map_type_strings(type, subtype, ctrl);

    // Derive pregap and pregap_dv as Beetle does
    int32 pregap_fixed = (trackno == 1) ? 150 : ((pgtype[0] == 'V') ? 0 : pregap);
    int32 pregap_dv    = (pgtype[0] == 'V') ? pregap : 0;

    // Logical LBA advances only by fixed pregap; variable pregap sectors
    // exist in file layout but do not advance the logical track start.
    plba += pregap_fixed;

    // Fill track map and TOC
    track_map[trackno].lba = plba;
    track_map[trackno].sectors = frames - pregap_dv;
    track_map[trackno].file_offset = file_offset + pregap_dv;
    track_map[trackno].control = ctrl;
    track_map[trackno].pregap = pregap_fixed;
    track_map[trackno].pregap_dv = pregap_dv;
    track_map[trackno].postgap = postgap;
    // Default: no swap; enable only if subtype hints MSB/BE explicitly.
    bool is_audio = (strcasecmp(type, "AUDIO") == 0);
    bool msb_hint = (strcasestr(subtype, "MSB") != nullptr) || (strcasestr(subtype, "BE") != nullptr);
    track_map[trackno].audio_msb_first = (is_audio && msb_hint);
    track_map[trackno].di_format = (is_audio ? 0 : 1);

    toc.tracks[trackno].lba = plba;
    toc.tracks[trackno].adr = ADR_CURPOS;
    toc.tracks[trackno].control = ctrl;
    toc.tracks[trackno].valid = true;

    if (strcasestr(type, "MODE2") != nullptr)
      any_mode2 = true;

    min_track = std::min(min_track, trackno);
    max_track = std::max(max_track, trackno);

    // Advance file offset through file layout: variable pregap, track data, postgap, and 4-frame padding
    file_offset += pregap_dv;
    file_offset += frames - pregap_dv;
    file_offset += postgap;
    int pad = ((frames + 3) & ~3) - frames;
    file_offset += pad;

    // Advance logical LBA through logical sectors and postgap
    plba += (frames - pregap_dv);
    plba += postgap;

    // Total sectors includes fixed pregap of track 1 like Beetle
    computed_total += (trackno == 1) ? frames : (frames + pregap_fixed);

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
    total_frames = (int32)((computed_total > 0) ? computed_total : total_frames);
  }
  else
  {
    toc.first_track = (uint8)std::max(1, min_track);
    toc.last_track = (uint8)std::min(99, max_track);
    // Use plba as the disc length; it reflects logical progression including postgaps.
    total_frames = plba;
  }

  toc.disc_type = any_mode2 ? DISC_TYPE_CD_XA : DISC_TYPE_CDDA_OR_M1;

  // Leadout based on total_frames
  toc.tracks[100].lba = total_frames;
  toc.tracks[100].adr = ADR_CURPOS;
  toc.tracks[100].control = (toc.last_track ? toc.tracks[toc.last_track].control : 0);
  toc.tracks[100].valid = true;
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
    uint8 data_synth_mode = (toc.disc_type == DISC_TYPE_CD_XA) ? 0x02 : 0x01;
    synth_leadout_sector_lba(data_synth_mode, toc, lba, buf);
    return;
  }

  // Determine track and relative position within track
  int trk = toc.FindTrackByLBA((uint32)lba);
  if (trk <= 0) trk = toc.first_track ? toc.first_track : 1;
  const TrackMap& tm = track_map[trk];
  const int32 rel = lba - tm.lba;

  if (rel < 0 || rel >= tm.sectors)
  {
    // Track-level pregap/postgap: synthesize sector content
    uint8 data_synth_mode = (toc.disc_type == DISC_TYPE_CD_XA) ? 0x02 : 0x01;
    synth_udapp_sector_lba(data_synth_mode, toc, lba, 0, buf);
    return;
  }

  // Map to CHD frame using Beetle math: cad = (lba - track_lba) + FileOffset
  const uint32 cad = (uint32)((int32)lba - (int32)tm.lba) + (uint32)tm.file_offset;
  const uint32 hunknum = cad / frames_per_hunk;
  const uint32 hunkofs = (cad % frames_per_hunk) * bytes_per_frame;

  // Sanity checks to avoid out-of-bounds reads on malformed/odd CHDs
  if (frames_per_hunk == 0)
  {
    throw MDFN_Error(0, _("Invalid CHD layout: frames_per_hunk computed as 0 (hunkbytes=%u, bpf=%u)"), (unsigned)bytes_per_hunk, (unsigned)bytes_per_frame);
  }
  if ((uint64)hunkofs + (uint64)bytes_per_frame > (uint64)bytes_per_hunk)
  {
    throw MDFN_Error(0, _("CHD hunk offset overflow: hunkofs=%u bpf=%u hunkbytes=%u (cad=%u, hunknum=%u, fph=%u)"),
                     (unsigned)hunkofs, (unsigned)bytes_per_frame, (unsigned)bytes_per_hunk,
                     (unsigned)cad, (unsigned)hunknum, (unsigned)frames_per_hunk);
  }

//  if (lba >= 0 && lba < 150)
//  {
//    MDFN_printf("CHDDBG map: LBA=%d trk=%d track_lba=%d rel=%d FileOffset=%d cad=%u hunknum=%u hunkofs=%u BPF=%u FPH=%u subcode=%d\n",
//                (int)lba, trk, (int)tm.lba, (int)rel, (int)tm.file_offset,
//                (unsigned)cad, (unsigned)hunknum, (unsigned)hunkofs, (unsigned)bytes_per_frame, (unsigned)frames_per_hunk, (int)subcode_included);
//  }

  ensure_hunk_loaded(hunknum);

  const uint8* src = &hunk_buf[hunkofs];

  // Always provide 2352 bytes of sector data
  memcpy(buf, src, 2352);
  // Fill PW: copy from CHD if present, else synthesize program-area Q; validate Q either way
  if (subcode_included)
  {
    memcpy(buf + 2352, src + 2352, 96);
    if(!qpw_is_valid_curpos(buf + 2352))
      synth_program_qpw(toc, lba, buf + 2352);
  }
  else
  {
    synth_program_qpw(toc, lba, buf + 2352);
  }

//  if (lba >= 0 && lba < 150)
//  {
//    MDFN_printf("CHDDBG sync: %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
//                src[0], src[1], src[2], src[3], src[4], src[5], src[6], src[7], src[8], src[9], src[10], src[11]);
//  }

  // Swap audio endianness if needed
  if (tm.di_format == 0 && tm.audio_msb_first)
    Endian_A16_Swap(buf, 588 * 2);

  // For data tracks, ensure sector is in the expected descrambled format.
  if (tm.di_format != 0)
  {
    const uint8 mode = buf[12 + 3];
    const bool is_xa = (mode == 2);
    // Only check/correct for Mode 1 or Mode 2 Form 1 (Form 2 lacks EDC in same way)
    const bool maybe_form2 = (buf[12 + 6] & 0x20) != 0; // XA form2 if set
    if (!maybe_form2)
    {
      using namespace CDUtility;
      if (!edc_check(buf, is_xa))
      {
        // Try toggling scramble state (XOR is symmetric). If EDC then passes, keep it.
        scrambleize_data_sector(buf);
        if (!edc_check(buf, is_xa))
        {
          // Revert if still bad to avoid leaving garbage; toggle back.
          scrambleize_data_sector(buf);
        }
      }
    }
  }
}

bool CDAccess_CHD::Fast_Read_Raw_PW_TSRE(uint8* pwbuf, int32 lba) const noexcept
{
  // Always provide PW by synthesis to keep this path thread-safe and re-entrant.
  if (lba >= total_frames)
  {
    subpw_synth_leadout_lba(toc, lba, pwbuf);
    return true;
  }

  // Determine track and relative position
  int trk = toc.FindTrackByLBA((uint32)lba);
  if (trk <= 0) trk = toc.first_track ? toc.first_track : 1;
  const TrackMap& tm = track_map[trk];
  const int32 rel = lba - tm.lba;

  if (rel < 0 || rel >= tm.sectors)
  {
    // Pregap/postgap subcode
    subpw_synth_udapp_lba(toc, lba, 0, pwbuf);
    return true;
  }

  // Program-area Q
  synth_program_qpw(toc, lba, pwbuf);
  return true;
}

void CDAccess_CHD::Read_TOC(CDUtility::TOC* out_toc)
{
  *out_toc = toc;
}

} // namespace Mednafen
