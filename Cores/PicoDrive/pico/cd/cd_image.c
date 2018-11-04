/*
 * CD image handler
 * (C) notaz, 2007,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"
#include "genplus_macros.h"
#include "cdd.h"
#include "cue.h"

static int handle_mp3(const char *fname, int index)
{
  track_t *track = &cdd.toc.tracks[index];
  FILE *tmp_file;
  int kBps;
  int fs, ret;

  tmp_file = fopen(fname, "rb");
  if (tmp_file == NULL)
    return -1;

  ret = fseek(tmp_file, 0, SEEK_END);
  fs = ftell(tmp_file);
  fseek(tmp_file, 0, SEEK_SET);

#ifdef _PSP_FW_VERSION
  // some systems (like PSP) can't have many open files at a time,
  // so we work with their names instead.
  fclose(tmp_file);
  tmp_file = (void *) strdup(fname);
#endif

  kBps = mp3_get_bitrate(tmp_file, fs) / 8;
  if (ret != 0 || kBps <= 0)
  {
    elprintf(EL_STATUS, "track %2i: mp3 bitrate %i", index+1, kBps);
#ifdef _PSP_FW_VERSION
    free(tmp_file);
#else
    fclose(tmp_file);
#endif
    return -1;
  }

  track->fd = tmp_file;
  track->offset = 0;

  fs *= 75;
  fs /= kBps * 1000;
  return fs;
}

static void to_upper(char *d, const char *s)
{
  for (; *s != 0; d++, s++) {
    if ('a' <= *s && *s <= 'z')
      *d = *s - 'a' + 'A';
    else
      *d = *s;
  }
}

// cdd.c uses lba - 150
static void sprintf_lba(char *buf, size_t size, int lba)
{
  lba += 150;
  snprintf(buf, size, "%02d:%02d:%02d", lba / 60 / 75,
    (lba / 75) % 60, lba % 75);
}

int load_cd_image(const char *cd_img_name, int *type)
{
  static const char *exts[] = {
    "%02d.mp3", " %02d.mp3", "-%02d.mp3", "_%02d.mp3", " - %02d.mp3",
    "%d.mp3", " %d.mp3", "-%d.mp3", "_%d.mp3", " - %d.mp3",
  };
  int i, j, n, lba, index, length, ret;
  int iso_name_len, missed, cd_img_sectors;
  char tmp_name[256], tmp_ext[10], tmp_ext_u[10];
  track_t *tracks = cdd.toc.tracks;
  cue_data_t *cue_data = NULL;
  pm_file *pmf;

  if (PicoCDLoadProgressCB != NULL)
    PicoCDLoadProgressCB(cd_img_name, 1);

  Pico_mcd->cdda_type = CT_UNKNOWN;

  /* is this a .cue? */
  cue_data = cue_parse(cd_img_name);
  if (cue_data != NULL) {
    cd_img_name = cue_data->tracks[1].fname;
    *type = cue_data->tracks[1].type;
  }

  pmf = pm_open(cd_img_name);
  if (pmf == NULL)
  {
    if (cue_data != NULL)
      cue_destroy(cue_data);
    return -1;
  }
  tracks[0].fd = pmf;

  if (*type == CT_ISO)
       cd_img_sectors = pmf->size >>= 11;  // size in sectors
  else cd_img_sectors = pmf->size /= 2352;

  // cdd.c operates with lba - 150
  tracks[0].start = 0;
  tracks[0].end = cd_img_sectors;
  tracks[0].offset = 0;

  sprintf_lba(tmp_ext, sizeof(tmp_ext), 0);
  elprintf(EL_STATUS, "Track  1: %s %9i DATA  %s",
    tmp_ext, tracks[0].end, cd_img_name);

  lba = cd_img_sectors;

  if (cue_data != NULL)
  {
    if (cue_data->tracks[2].fname == NULL) {
      // NULL fname means track2 is in same file as track1
      lba = tracks[0].end = cue_data->tracks[2].sector_offset;
    }
    i = 100 / cue_data->track_count + 1; // progress display

    for (n = 2; n <= cue_data->track_count; n++)
    {
      if (PicoCDLoadProgressCB != NULL)
        PicoCDLoadProgressCB(cd_img_name, i * n);

      index = n - 1;
      lba += cue_data->tracks[n].pregap;
      if (cue_data->tracks[n].type == CT_MP3) {
        ret = handle_mp3(cue_data->tracks[n].fname, index);
        if (ret < 0)
          break;
        length = ret;
      }
      else if (cue_data->tracks[n].fname != NULL)
      {
        pm_file *f = pm_open(cue_data->tracks[n].fname);
        if (f != NULL)
        {
          // assume raw, ignore header for wav..
          tracks[index].fd = f;
          tracks[index].offset = cue_data->tracks[n].sector_offset;
          length = f->size / 2352;
        }
        else
        {
          elprintf(EL_STATUS, "track %2i (%s): can't determine length",
            n, cue_data->tracks[n].fname);
          tracks[index].offset = 0;
          length = 2*75;
        }
      }
      else
      {
        if (n < cue_data->track_count)
          length = cue_data->tracks[n+1].sector_offset -
            cue_data->tracks[n].sector_offset;
        else
          length = cd_img_sectors - cue_data->tracks[n].sector_offset;
        tracks[index].offset = cue_data->tracks[n].sector_offset;
      }

      if (cue_data->tracks[n].sector_xlength != 0)
        // overriden by custom cue command
        length = cue_data->tracks[n].sector_xlength;

      Pico_mcd->cdda_type = cue_data->tracks[n].type;

      tracks[index].start = lba;
      lba += length;
      tracks[index].end = lba;

      sprintf_lba(tmp_ext, sizeof(tmp_ext), tracks[index].start);
      elprintf(EL_STATUS, "Track %2i: %s %9i AUDIO %s",
        n, tmp_ext, length, cue_data->tracks[n].fname);
    }
    goto finish;
  }

  /* mp3 track autosearch, Gens-like */
  iso_name_len = strlen(cd_img_name);
  if (iso_name_len >= sizeof(tmp_name))
    iso_name_len = sizeof(tmp_name) - 1;

  for (n = 2, i = 0, missed = 0; i < 100 && missed < 4; i++)
  {
    if (PicoCDLoadProgressCB != NULL && i > 1)
      PicoCDLoadProgressCB(cd_img_name, i + (100-i)*missed/4);

    for (j = 0; j < sizeof(exts)/sizeof(char *); j++)
    {
      int ext_len;
      char *p;

      index = n - 1;

      snprintf(tmp_ext, sizeof(tmp_ext), exts[j], i);
      ext_len = strlen(tmp_ext);
      to_upper(tmp_ext_u, tmp_ext);

      memcpy(tmp_name, cd_img_name, iso_name_len + 1);
      p = tmp_name + iso_name_len - 4;

      strcpy(p, tmp_ext);
      ret = handle_mp3(tmp_name, index);
      if (ret <= 0) {
        strcpy(p, tmp_ext_u);
        ret = handle_mp3(tmp_name, index);
      }

      if (ret <= 0 && i > 1 && iso_name_len > ext_len) {
        p = tmp_name + iso_name_len - ext_len;
        strcpy(p, tmp_ext);
        ret = handle_mp3(tmp_name, index);
        if (ret <= 0) {
          strcpy(p, tmp_ext_u);
          ret = handle_mp3(tmp_name, index);
        }
      }

      if (ret > 0)
      {
        length = ret;
        tracks[index].start = lba;
        lba += length;
        tracks[index].end = lba;

        Pico_mcd->cdda_type = CT_MP3;

        sprintf_lba(tmp_ext, sizeof(tmp_ext), tracks[index].start);
        elprintf(EL_STATUS, "Track %2i: %s %9i AUDIO - %s",
          n, tmp_ext, length, tmp_name);

        n++;
        missed = 0;
        break;
      }
    }
    if (ret <= 0 && i > 1)
      missed++;
  }

finish:
  cdd.toc.last = n - 1;
  cdd.toc.end = lba;

  sprintf_lba(tmp_ext, sizeof(tmp_ext), cdd.toc.end);
  elprintf(EL_STATUS, "End CD -  %s\n", tmp_ext);

  if (PicoCDLoadProgressCB != NULL)
    PicoCDLoadProgressCB(cd_img_name, 100);

  if (cue_data != NULL)
    cue_destroy(cue_data);

  return 0;
}

// vim:shiftwidth=2:ts=2:expandtab
