/*
 * PicoDrive
 * (C) notaz, 2006-2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <string.h>
#include "pico_int.h"
#include "cd/cue.h"

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

static int detect_media(const char *fname)
{
  static const short sms_offsets[] = { 0x7ff0, 0x3ff0, 0x1ff0 };
  static const char *sms_exts[] = { "sms", "gg", "sg" };
  static const char *md_exts[] = { "gen", "bin", "smd" };
  char buff0[32], buff[32];
  unsigned short *d16;
  pm_file *pmf;
  char ext[5];
  int i;

  get_ext(fname, ext);

  // detect wrong extensions
  if (!strcmp(ext, ".srm") || !strcmp(ext, "s.gz") || !strcmp(ext, ".mds")) // s.gz ~ .mds.gz
    return PM_BAD_DETECT;

  /* don't believe in extensions, except .cue */
  if (strcasecmp(ext, ".cue") == 0)
    return PM_CD;

  pmf = pm_open(fname);
  if (pmf == NULL)
    return PM_BAD_DETECT;

  if (pm_read(buff0, 32, pmf) != 32) {
    pm_close(pmf);
    return PM_BAD_DETECT;
  }

  if (strncasecmp("SEGADISCSYSTEM", buff0 + 0x00, 14) == 0 ||
      strncasecmp("SEGADISCSYSTEM", buff0 + 0x10, 14) == 0) {
    pm_close(pmf);
    return PM_CD;
  }

  /* check for SMD evil */
  if (pmf->size >= 0x4200 && (pmf->size & 0x3fff) == 0x200) {
    if (pm_seek(pmf, sms_offsets[0] + 0x200, SEEK_SET) == sms_offsets[0] + 0x200 &&
        pm_read(buff, 16, pmf) == 16 &&
        strncmp("TMR SEGA", buff, 8) == 0)
      goto looks_like_sms;

    /* could parse further but don't bother */
    goto extension_check;
  }

  /* MD header? Act as TMSS BIOS here */
  if (pm_seek(pmf, 0x100, SEEK_SET) == 0x100 && pm_read(buff, 16, pmf) == 16) {
    if (strncmp(buff, "SEGA", 4) == 0 || strncmp(buff, " SEG", 4) == 0)
      goto looks_like_md;
  }

  for (i = 0; i < ARRAY_SIZE(sms_offsets); i++) {
    if (pm_seek(pmf, sms_offsets[i], SEEK_SET) != sms_offsets[i])
      continue;

    if (pm_read(buff, 16, pmf) != 16)
      continue;

    if (strncmp("TMR SEGA", buff, 8) == 0)
      goto looks_like_sms;
  }

extension_check:
  /* probably some headerless thing. Maybe check the extension after all. */
  for (i = 0; i < ARRAY_SIZE(md_exts); i++)
    if (strcasecmp(pmf->ext, md_exts[i]) == 0)
      goto looks_like_md;

  for (i = 0; i < ARRAY_SIZE(sms_exts); i++)
    if (strcasecmp(pmf->ext, sms_exts[i]) == 0)
      goto looks_like_sms;

  /* If everything else fails, make a guess on the reset vector */
  d16 = (unsigned short *)(buff0 + 4);
  if ((((d16[0] << 16) | d16[1]) & 0xffffff) >= pmf->size) {
    lprintf("bad MD reset vector, assuming SMS\n");
    goto looks_like_sms;
  }

looks_like_md:
  pm_close(pmf);
  return PM_MD_CART;

looks_like_sms:
  pm_close(pmf);
  return PM_MARK3;
}

/* checks if fname points to valid MegaCD image */
int PicoCdCheck(const char *fname_in, int *pregion)
{
  const char *fname = fname_in;
  unsigned char buf[32];
  pm_file *cd_f;
  int region = 4; // 1: Japan, 4: US, 8: Europe
  char ext[5];
  cue_track_type type = CT_UNKNOWN;
  cue_data_t *cue_data = NULL;

  // opens a cue, or searches for one
  cue_data = cue_parse(fname_in);
  if (cue_data != NULL) {
    fname = cue_data->tracks[1].fname;
    type  = cue_data->tracks[1].type;
  }
  else {
    get_ext(fname_in, ext);
    if (strcasecmp(ext, ".cue") == 0)
      return -1;
  }

  cd_f = pm_open(fname);
  if (cue_data != NULL)
    cue_destroy(cue_data);

  if (cd_f == NULL) return 0; // let the upper level handle this

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
  const char *carthw_cfg_fname,
  const char *(*get_bios_filename)(int *region, const char *cd_fname),
  void (*do_region_override)(const char *media_filename))
{
  const char *rom_fname = filename;
  enum media_type_e media_type;
  enum cd_img_type cd_img_type = CIT_NOT_CD;
  unsigned char *rom_data = NULL;
  unsigned int rom_size = 0;
  pm_file *rom = NULL;
  int cd_region = 0;
  int ret;

  media_type = detect_media(filename);
  if (media_type == PM_BAD_DETECT)
    goto out;

  if ((PicoAHW & PAHW_MCD) && Pico_mcd != NULL)
    cdd_unload();
  PicoCartUnload();
  PicoAHW = 0;
  PicoQuirks = 0;

  if (media_type == PM_CD)
  {
    // check for MegaCD image
    cd_img_type = PicoCdCheck(filename, &cd_region);
    if ((int)cd_img_type >= 0 && cd_img_type != CIT_NOT_CD)
    {
      // valid CD image, ask frontend for BIOS..
      rom_fname = NULL;
      if (get_bios_filename != NULL)
        rom_fname = get_bios_filename(&cd_region, filename);
      if (rom_fname == NULL) {
        media_type = PM_BAD_CD_NO_BIOS;
        goto out;
      }

      PicoAHW |= PAHW_MCD;
    }
    else {
      media_type = PM_BAD_CD;
      goto out;
    }
  }
  else if (media_type == PM_MARK3) {
    lprintf("detected SMS ROM\n");
    PicoAHW = PAHW_SMS;
  }

  rom = pm_open(rom_fname);
  if (rom == NULL) {
    lprintf("Failed to open ROM");
    media_type = PM_ERROR;
    goto out;
  }

  ret = PicoCartLoad(rom, &rom_data, &rom_size, (PicoAHW & PAHW_SMS) ? 1 : 0);
  pm_close(rom);
  if (ret != 0) {
    if      (ret == 2) lprintf("Out of memory");
    else if (ret == 3) lprintf("Read failed");
    else               lprintf("PicoCartLoad() failed.");
    media_type = PM_ERROR;
    goto out;
  }

  // detect wrong files
  if (strncmp((char *)rom_data, "Pico", 4) == 0) {
    lprintf("savestate selected?\n");
    media_type = PM_BAD_DETECT;
    goto out;
  }

  if (!(PicoAHW & PAHW_SMS)) {
    unsigned short *d = (unsigned short *)(rom_data + 4);
    if ((((d[0] << 16) | d[1]) & 0xffffff) >= (int)rom_size) {
      lprintf("bad reset vector\n");
      media_type = PM_BAD_DETECT;
      goto out;
    }
  }

  // load config for this ROM (do this before insert to get correct region)
  if (!(PicoAHW & PAHW_MCD)) {
    memcpy(media_id_header, rom_data + 0x100, sizeof(media_id_header));
    if (do_region_override != NULL)
      do_region_override(filename);
  }

  if (PicoCartInsert(rom_data, rom_size, carthw_cfg_fname)) {
    media_type = PM_ERROR;
    goto out;
  }
  rom_data = NULL; // now belongs to PicoCart
  Pico.m.ncart_in = 0;

  // insert CD if it was detected
  if (cd_img_type != CIT_NOT_CD) {
    ret = cdd_load(filename, cd_img_type);
    if (ret != 0) {
      PicoCartUnload();
      media_type = PM_BAD_CD;
      goto out;
    }
    Pico.m.ncart_in = 1;
  }

  if (PicoQuirks & PQUIRK_FORCE_6BTN)
    PicoSetInputDevice(0, PICO_INPUT_PAD_6BTN);

out:
  if (rom_data)
    free(rom_data);
  return media_type;
}

// vim:shiftwidth=2:ts=2:expandtab
