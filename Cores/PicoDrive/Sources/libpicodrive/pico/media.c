/*
 * PicoDrive
 * (C) notaz, 2006-2010,2013
 * (C) irixxxx, 2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "pico_int.h"
#include "cd/cd_parse.h"

unsigned char media_id_header[0x100];

static void strlwr_(char *string)
{
  char *p;
  for (p = string; *p; p++)
    if ('A' <= *p && *p <= 'Z')
      *p += 'a' - 'A';
}

static void get_ext(const char *file, char *ext)
{
  const char *p;

  p = file + strlen(file) - 4;
  if (p < file) p = file;
  strncpy(ext, p, 4);
  ext[4] = 0;
  strlwr_(ext);
}

static int detect_media(const char *fname, const unsigned char *rom, unsigned int romsize)
{
  static const short sms_offsets[] = { 0x7ff0, 0x3ff0, 0x1ff0 };
  static const char *sms_exts[] = { "sms", "gg", "sg", "sc" };
  static const char *md_exts[] = { "gen", "smd", "md", "32x" };
  static const char *pico_exts[] = { "pco" };
  char buff0[512], buff[32];
  unsigned short *d16 = NULL;
  pm_file *pmf = NULL;
  const char *ext_ptr = NULL;
  char ext[8];
  int i;

  ext[0] = '\0';
  if ((ext_ptr = strrchr(fname, '.'))) {
    strncpy(ext, ext_ptr + 1, sizeof(ext));
    ext[sizeof(ext) - 1] = '\0';
  }

  // detect wrong extensions
  if (!strcasecmp(ext, "srm") || !strcasecmp(ext, "gz")) // s.gz ~ .mds.gz
    return PM_BAD_DETECT;

  /* don't believe in extensions, except .cue and .chd */
  if (strcasecmp(ext, "cue") == 0 || strcasecmp(ext, "chd") == 0)
    return PM_CD;

  /* Open rom file, if required */
  if (!rom) {
    pmf = pm_open(fname);
    if (pmf == NULL)
      return PM_BAD_DETECT;
    romsize = pmf->size;
  }

  if (!rom) {
    if (pm_read(buff0, 512, pmf) != 512) {
      pm_close(pmf);
      return PM_BAD_DETECT;
    }
  } else {
    if (romsize < 512)
      return PM_BAD_DETECT;
    memcpy(buff0, rom, 512);
  }

  if (strncasecmp("SEGADISCSYSTEM", buff0 + 0x00, 14) == 0 ||
      strncasecmp("SEGADISCSYSTEM", buff0 + 0x10, 14) == 0) {
    pm_close(pmf);
    return PM_CD;
  }

  /* check for SMD evil */
  if (romsize >= 0x4200 && (romsize & 0x3fff) == 0x200) {
    buff[0] = '\0';

    if (!rom) {
      if (pm_seek(pmf, sms_offsets[0] + 0x200, SEEK_SET) == sms_offsets[0] + 0x200)
        pm_read(buff, 16, pmf);
    } else {
      if (romsize >= sms_offsets[0] + 0x200 + 16)
        memcpy(buff, rom + sms_offsets[0] + 0x200, 16);
    }

    if (strncmp("TMR SEGA", buff, 8) == 0)
      goto looks_like_sms;

    /* could parse further but don't bother */
    goto extension_check;
  }

  /* fetch header info */
  memset(buff, '\0', 17);
  if (!rom) {
    if (pm_seek(pmf, 0x100, SEEK_SET) == 0x100)
      pm_read(buff, 16, pmf);
  } else {
    if (romsize >= 0x100 + 16)
      memcpy(buff, rom + 0x100, 16);
  }
  /* PICO header? Almost always appropriately marked */
  if (strstr(buff, " PICO "))
    goto looks_like_pico;
  /* MD header? Act as TMSS BIOS here */
  if (strncmp(buff, "SEGA", 4) == 0 || strncmp(buff, " SEG", 4) == 0)
    goto looks_like_md;

  for (i = 0; i < ARRAY_SIZE(sms_offsets); i++) {
    if (!rom) {
      if (pm_seek(pmf, sms_offsets[i], SEEK_SET) != sms_offsets[i])
        continue;

      if (pm_read(buff, 16, pmf) != 16)
        continue;
    } else {
      if (romsize < sms_offsets[i] + 16)
        continue;

      memcpy(buff, rom + sms_offsets[i], 16);
    }

    if (strncmp("TMR SEGA", buff, 8) == 0)
      goto looks_like_sms;
  }

extension_check:
  /* probably some headerless thing. Maybe check the extension after all. */
  ext_ptr = pmf && *pmf->ext ? pmf->ext : ext;

  for (i = 0; i < ARRAY_SIZE(md_exts); i++)
    if (strcasecmp(ext_ptr, md_exts[i]) == 0)
      goto looks_like_md;

  for (i = 0; i < ARRAY_SIZE(sms_exts); i++)
    if (strcasecmp(ext_ptr, sms_exts[i]) == 0)
      goto looks_like_sms;

  for (i = 0; i < ARRAY_SIZE(pico_exts); i++)
    if (strcasecmp(ext_ptr, pico_exts[i]) == 0)
      goto looks_like_pico;

  /* If everything else fails, make a guess on the reset vector */
  d16 = (unsigned short *)(buff0 + 4);
  if ((((d16[0] << 16) | d16[1]) & 0xffffff) >= romsize) {
    lprintf("bad MD reset vector, assuming SMS\n");
    goto looks_like_sms;
  }
  d16 = (unsigned short *)(buff0 + 0x1a0);
  if ((((d16[0] << 16) | d16[1]) & 0xffffff) != 0) {
    lprintf("bad MD rom start, assuming SMS\n");
    goto looks_like_sms;
  }

looks_like_md:
  pm_close(pmf);
  return PM_MD_CART;

looks_like_sms:
  pm_close(pmf);
  return PM_MARK3;

looks_like_pico:
  pm_close(pmf);
  return PM_PICO;
}

/* checks if fname points to valid MegaCD image */
int PicoCdCheck(const char *fname_in, int *pregion)
{
  const char *fname = fname_in;
  unsigned char buf[32];
  pm_file *cd_f;
  int region = 4; // 1: Japan, 4: US, 8: Europe
  char ext[5];
  enum cd_track_type type = CT_UNKNOWN;
  cd_data_t *cd_data = NULL;

  // opens a cue, or searches for one
  if (!cd_data && (cd_data = cue_parse(fname_in)) == NULL) {
    get_ext(fname_in, ext);
    if (strcasecmp(ext, ".cue") == 0)
      return -1;
  }
  // opens a chd
  if (!cd_data && (cd_data = chd_parse(fname_in)) == NULL) {
    get_ext(fname_in, ext);
    if (strcasecmp(ext, ".chd") == 0)
      return -1;
  }

  if (cd_data != NULL) {
    // 1st track contains the code
    fname = cd_data->tracks[1].fname;
    type  = cd_data->tracks[1].type;
  }

  cd_f = pm_open(fname);
  cdparse_destroy(cd_data);
  if (cd_f == NULL) return CT_UNKNOWN; // let the upper level handle this

  if (pm_read(buf, 32, cd_f) != 32) {
    pm_close(cd_f);
    return -1;
  }

  if (!strncasecmp("SEGADISCSYSTEM", (char *)buf+0x00, 14)) {
    if (type && type != CT_ISO)
      elprintf(EL_STATUS, ".cue has wrong type: %i", type);
    type = CT_ISO;       // Sega CD (ISO)
  }
  if (!strncasecmp("SEGADISCSYSTEM", (char *)buf+0x10, 14)) {
    if (type && type != CT_BIN)
      elprintf(EL_STATUS, ".cue has wrong type: %i", type);
    type = CT_BIN;       // Sega CD (BIN)
  }

  if (type == CT_UNKNOWN) {
    pm_close(cd_f);
    return 0;
  }

  pm_seek(cd_f, (type == CT_ISO) ? 0x100 : 0x110, SEEK_SET);
  pm_read(media_id_header, sizeof(media_id_header), cd_f);

  /* it seems we have a CD image here. Try to detect region now.. */
  pm_seek(cd_f, (type == CT_ISO) ? 0x100+0x10B : 0x110+0x10B, SEEK_SET);
  pm_read(buf, 1, cd_f);
  pm_close(cd_f);

  if (buf[0] == 0x64) region = 8; // EU
  if (buf[0] == 0xa1) region = 1; // JAP

  lprintf("detected %s Sega/Mega CD image with %s region\n",
    type == CT_BIN ? "BIN" : "ISO", region != 4 ? (region == 8 ? "EU" : "JAP") : "USA");

  if (pregion != NULL)
    *pregion = region;

  return type;
}

enum media_type_e PicoLoadMedia(const char *filename,
  const unsigned char *rom, unsigned int romsize,
  const char *carthw_cfg_fname,
  const char *(*get_bios_filename)(int *region, const char *cd_fname),
  const char *(*get_msu_filename)(const char *cd_fname),
  void (*do_region_override)(const char *media_filename))
{
  const char *rom_fname = filename;
  enum media_type_e media_type;
  enum cd_track_type cd_img_type = CT_UNKNOWN;
  pm_file *rom_file = NULL;
  unsigned char *rom_data = NULL;
  unsigned int rom_size = 0;
  int cd_region = 0;
  int ret;

  media_type = detect_media(filename, rom, romsize);
  if (media_type == PM_BAD_DETECT)
    goto out;

  if ((PicoIn.AHW & PAHW_MCD) && Pico_mcd != NULL)
    cdd_unload();
  PicoCartUnload();
  PicoIn.AHW = 0;
  PicoIn.quirks = 0;

  if (media_type == PM_CD)
  {
    // check for MegaCD image
    cd_img_type = PicoCdCheck(filename, &cd_region);
    if ((int)cd_img_type >= 0 && cd_img_type != CT_UNKNOWN)
    {
      // valid CD image, ask frontend for BIOS.
      rom_fname = NULL;
      if (get_bios_filename != NULL)
        rom_fname = get_bios_filename(&cd_region, filename);
      rom_file = pm_open(rom_fname);

      // ask frontend if there's an MSU/MD+ rom
      rom_fname = NULL;
      if (get_msu_filename != NULL)
        rom_fname = get_msu_filename(filename);

      // BIOS is required for CD games, but MSU/MD+ usually doesn't need it
      if (rom_file == NULL && rom_fname == NULL) {
        lprintf("opening BIOS failed\n");
        media_type = PM_BAD_CD_NO_BIOS;
        goto out;
      }

      if (rom_file != NULL) {
        ret = PicoCartLoad(rom_file, NULL, 0, &rom_data, &rom_size, 0);
        if (ret != 0) {
          lprintf("reading BIOS failed\n");
          media_type = PM_ERROR;
          goto out;
        }

        // copy BIOS and close file
        PicoCreateMCD(rom_data, rom_size);

        PicoCartUnload();
        pm_close(rom_file);
        rom_file = NULL;
        rom_size = 0;
      }

      // if there is an MSU ROM, its name is now in rom_fname for loading
      PicoIn.AHW |= PAHW_MCD;
    }
    else {
      media_type = PM_BAD_CD;
      goto out;
    }
  }
  else if (media_type == PM_MARK3) {
    PicoIn.AHW = PAHW_SMS;
  }
  else if (media_type == PM_PICO) {
    PicoIn.AHW = PAHW_PICO;
  }

  if (rom == NULL && rom_fname != NULL) {
    rom_file = pm_open(rom_fname);
    if (rom_file == NULL) {
      lprintf("Failed to open ROM\n");
      media_type = PM_ERROR;
      goto out;
    }
  }

  if (rom != NULL || rom_file != NULL) {
    ret = PicoCartLoad(rom_file, rom, romsize, &rom_data, &rom_size, (PicoIn.AHW & PAHW_SMS) ? 1 : 0);
    if (ret != 0) {
      if      (ret == 2) lprintf("Out of memory\n");
      else if (ret == 3) lprintf("Read failed\n");
      else               lprintf("PicoCartLoad() failed.\n");
      media_type = PM_ERROR;
      goto out;
    }

    // detect wrong files
    if (rom_strcmp(rom_data, rom_size, 0, "Pico") == 0) {
      lprintf("savestate selected?\n");
      media_type = PM_BAD_DETECT;
      goto out;
    }

    if (!(PicoIn.AHW & PAHW_SMS)) {
      unsigned short *d = (unsigned short *)(rom_data + 4);
      if ((((d[0] << 16) | d[1]) & 0xffffff) >= (int)rom_size) {
        lprintf("bad reset vector\n");
        media_type = PM_BAD_DETECT;
        goto out;
      }
    }

    // maybe we are loading MegaCD BIOS?
    if (!(PicoIn.AHW & PAHW_MCD) && rom_size <= 0x20000 && (!rom_strcmp(rom_data, rom_size, 0x124, "BOOT") ||
         !rom_strcmp(rom_data, rom_size, 0x128, "BOOT"))) {
      PicoIn.AHW |= PAHW_MCD;
      // copy to Pmcd as BIOS
      PicoCreateMCD(rom_data, rom_size);
      PicoCartUnload();
      rom_size = 0;
    }
  }

  if (!(PicoIn.AHW & PAHW_MCD)) {
    // load config for this ROM (do this before insert to get correct region)
    memcpy(media_id_header, rom_data + 0x100, sizeof(media_id_header));
    if (do_region_override != NULL)
      do_region_override(filename);
  }

  // simple test for GG. Do this here since m.hardware is nulled in Insert
  if ((PicoIn.AHW & PAHW_SMS) && !PicoIn.hwSelect) {
    const char *ext = NULL;
    if (rom_file && (*rom_file->ext != '\0')) {
      ext = rom_file->ext;
    }
    else if ((ext = strrchr(filename, '.'))) {
      if (*(++ext) == '\0') {
        ext = NULL;
      }
    }
    if (ext && !strcasecmp(ext,"gg")) {
      PicoIn.AHW |= PAHW_GG;
      lprintf("detected GG ROM\n");
    } else if (ext && !strcasecmp(ext,"sg")) {
      PicoIn.AHW |= PAHW_SG;
      lprintf("detected SG-1000 ROM\n");
    } else if (ext && !strcasecmp(ext,"sc")) {
      PicoIn.AHW |= PAHW_SC;
      lprintf("detected SC-3000 ROM\n");
    } else
      lprintf("detected SMS ROM\n");
  }

  // insert CD if it was detected
  Pico.m.ncart_in = 0;
  if (cd_img_type != CT_UNKNOWN) {
    ret = cdd_load(filename, cd_img_type);
    if (ret != 0) {
      PicoCartUnload();
      media_type = PM_BAD_CD;
      goto out;
    }
    if (Pico.romsize == 0)
      Pico.m.ncart_in = 1;
  }

  if (PicoCartInsert(rom_data, rom_size, carthw_cfg_fname)) {
    media_type = PM_ERROR;
    goto out;
  }
  rom_data = NULL; // now belongs to PicoCart

  if (PicoIn.quirks & PQUIRK_FORCE_6BTN)
    PicoSetInputDevice(0, PICO_INPUT_PAD_6BTN);

out:
  if (rom_file)
    pm_close(rom_file);
  if (rom_data)
    PicoCartUnload();
  return media_type;
}

// vim:shiftwidth=2:ts=2:expandtab
