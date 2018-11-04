/*  Copyright 2004-2008, 2013 Theo Berkau
    Copyright 2005 Joost Peters
    Copyright 2005-2006 Guillaume Duhamel
    
    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file cdbase.c
    \brief Dummy and ISO, BIN/CUE, MDS CD Interfaces
*/

#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#include <wchar.h>
#include "cdbase.h"
#include "error.h"
#include "debug.h"

#include <stdarg.h>

#ifdef __LIBRETRO__
#include "streams/file_stream_transforms.h"
#endif

#ifndef HAVE_STRICMP
#ifdef HAVE_STRCASECMP
#define stricmp strcasecmp
#endif
#endif

#ifndef HAVE_WFOPEN
static char * wcsdupstr(const wchar_t * path)
{
   char * mbs;
   size_t len = wcstombs(NULL, path, 0);
   if (len == (size_t) -1) return NULL;

   mbs = malloc(len);
   len = wcstombs(mbs, path, len);
   if (len == (size_t) -1)
   {
      free(mbs);
      return NULL;
   }

   return mbs;
}

static FILE * _wfopen(const wchar_t *wpath, const wchar_t *wmode)
{
   FILE * fd;
   char * path;
   char * mode;

   path = wcsdupstr(wpath);
   if (path == NULL) return NULL;

   mode = wcsdupstr(wmode);
   if (mode == NULL)
   {
      free(path);
      return NULL;
   }

   fd = fopen(path, mode);

   free(path);
   free(mode);

   return fd;
}
#endif

//////////////////////////////////////////////////////////////////////////////

// Contains the Dummy and ISO CD Interfaces

static int DummyCDInit(const char *);
static void DummyCDDeInit(void);
static int DummyCDGetStatus(void);
static s32 DummyCDReadTOC(u32 *);
static int DummyCDReadSectorFAD(u32, void *);
static void DummyCDReadAheadFAD(u32);

CDInterface DummyCD = {
CDCORE_DUMMY,
"Dummy CD Drive",
DummyCDInit,
DummyCDDeInit,
DummyCDGetStatus,
DummyCDReadTOC,
DummyCDReadSectorFAD,
DummyCDReadAheadFAD,
};

static int ISOCDInit(const char *);
static void ISOCDDeInit(void);
static int ISOCDGetStatus(void);
static s32 ISOCDReadTOC(u32 *);
static int ISOCDReadSectorFAD(u32, void *);
static void ISOCDReadAheadFAD(u32);

CDInterface ISOCD = {
CDCORE_ISO,
"ISO-File Virtual Drive",
ISOCDInit,
ISOCDDeInit,
ISOCDGetStatus,
ISOCDReadTOC,
ISOCDReadSectorFAD,
ISOCDReadAheadFAD,
};

//////////////////////////////////////////////////////////////////////////////
// Dummy Interface
//////////////////////////////////////////////////////////////////////////////

static int DummyCDInit(UNUSED const char *cdrom_name)
{
	// Initialization function. cdrom_name can be whatever you want it to
	// be. Obviously with some ports(e.g. the dreamcast port) you probably
	// won't even use it.
	return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void DummyCDDeInit(void)
{
	// Cleanup function. Enough said.
}

//////////////////////////////////////////////////////////////////////////////

static int DummyCDGetStatus(void)
{
	// This function is called periodically to see what the status of the
	// drive is.
	//
	// Should return one of the following values:
	// 0 - CD Present, disc spinning
	// 1 - CD Present, disc not spinning
	// 2 - CD not present
	// 3 - Tray open
	//
	// If you really don't want to bother too much with this function, just
	// return status 0. Though it is kind of nice when the bios's cd
	// player, etc. recognizes when you've ejected the tray and popped in
	// another disc.

	return 0;
}

//////////////////////////////////////////////////////////////////////////////

static s32 DummyCDReadTOC(UNUSED u32 *TOC)
{
	// The format of TOC is as follows:
	// TOC[0] - TOC[98] are meant for tracks 1-99. Each entry has the
	// following format:
	// bits 0 - 23: track FAD address
	// bits 24 - 27: track addr
	// bits 28 - 31: track ctrl
	//
	// Any Unused tracks should be set to 0xFFFFFFFF
	//
	// TOC[99] - Point A0 information 
	// Uses the following format:
	// bits 0 - 7: PFRAME(should always be 0)
	// bits 7 - 15: PSEC(Program area format: 0x00 - CDDA or CDROM,
	//                   0x10 - CDI, 0x20 - CDROM-XA)
	// bits 16 - 23: PMIN(first track's number)
	// bits 24 - 27: first track's addr
	// bits 28 - 31: first track's ctrl
	//
	// TOC[100] - Point A1 information
	// Uses the following format:
	// bits 0 - 7: PFRAME(should always be 0)
	// bits 7 - 15: PSEC(should always be 0)
	// bits 16 - 23: PMIN(last track's number)
	// bits 24 - 27: last track's addr
	// bits 28 - 31: last track's ctrl
	//
	// TOC[101] - Point A2 information
	// Uses the following format:
	// bits 0 - 23: leadout FAD address
	// bits 24 - 27: leadout's addr
	// bits 28 - 31: leadout's ctrl
	//
	// Special Note: To convert from LBA/LSN to FAD, add 150.

	return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int DummyCDReadSectorFAD(UNUSED u32 FAD, void * buffer)
{
	// This function is supposed to read exactly 1 -RAW- 2352-byte sector
	// at the specified FAD address to buffer. Should return true if
	// successful, false if there was an error.
	//
	// Special Note: To convert from FAD to LBA/LSN, minus 150.
	//
	// The whole process needed to be changed since I need more control
	// over sector detection, etc. Not to mention it means less work for
	// the porter since they only have to implement raw sector reading as
	// opposed to implementing mode 1, mode 2 form1/form2, -and- raw
	// sector reading.

	memset(buffer, 0, 2352);

	return 1;
}

//////////////////////////////////////////////////////////////////////////////

static void DummyCDReadAheadFAD(UNUSED u32 FAD)
{
	// This function is called to tell the driver which sector (FAD
	// address) is expected to be read next. If the driver supports
	// read-ahead, it should start reading the given sector in the
	// background while the emulation continues, so that when the
	// sector is actually read with ReadSectorFAD() it'll be available
	// immediately. (Note that there's no guarantee this sector will
	// actually be requested--the emulated CD might be stopped before
	// the sector is read, for example.)
	//
	// This function should NOT block. If the driver can't perform
	// asynchronous reads (or you just don't want to bother handling
	// them), make this function a no-op and just read sectors
	// normally.
}

//////////////////////////////////////////////////////////////////////////////
// ISO Interface
//////////////////////////////////////////////////////////////////////////////

typedef struct
{
   u8 ctl_addr;
   u32 fad_start;
   u32 fad_end;
   u32 file_offset;
   u32 sector_size;
   FILE *fp;
	FILE *sub_fp;
   int file_size;
   int file_id;
   int interleaved_sub;
} track_info_struct;

typedef struct
{
   u32 fad_start;
   u32 fad_end;
   track_info_struct *track;
   int track_num;
} session_info_struct;

typedef struct
{
   int session_num;
   session_info_struct *session;
} disc_info_struct;

#pragma pack(push, 1)
typedef struct
{
   u8 signature[16];
   u8 version[2];
   u16 medium_type;
   u16 session_count;
   u16 unused1[2];
   u16 bca_length;
   u32 unused2[2];
   u32 bca_offset;
   u32 unused3[6];
   u32 disk_struct_offset;
   u32 unused4[3];
   u32 sessions_blocks_offset;
   u32 dpm_blocks_offset;
   u32 enc_key_offset;
} mds_header_struct;

typedef struct
{
   s32 session_start;
   s32 session_end;
   u16 session_number;
   u8 total_blocks;
   u8 leadin_blocks;
   u16 first_track;
   u16 last_track;
   u32 unused;
   u32 track_blocks_offset;
} mds_session_struct;

typedef struct
{
   u8 mode;
   u8 subchannel_mode;
   u8 addr_ctl;
   u8 unused1;
   u8 track_num;
   u32 unused2;
   u8 m;
   u8 s;
   u8 f;
   u32 extra_offset;
   u16 sector_size;
   u8 unused3[18];
   u32 start_sector;
   u64 start_offset;
   u8 session;
   u8 unused4[3];
   u32 footer_offset;
   u8 unused5[24];
} mds_track_struct;

typedef struct
{
   u32 filename_offset;
   u32 is_widechar;
   u32 unused1;
   u32 unused2;
} mds_footer_struct;

#pragma pack(pop)

#define CCD_MAX_SECTION 20
#define CCD_MAX_NAME 30
#define CCD_MAX_VALUE 20

typedef struct
{
	char section[CCD_MAX_SECTION];
	char name[CCD_MAX_NAME];
	char value[CCD_MAX_VALUE];
} ccd_dict_struct;

typedef struct
{
	ccd_dict_struct *dict;
	int num_dict;
} ccd_struct;

static const s8 syncHdr[12] = { 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00 };
enum IMG_TYPE { IMG_NONE, IMG_ISO, IMG_BINCUE, IMG_MDS, IMG_CCD, IMG_NRG };
enum IMG_TYPE imgtype = IMG_ISO;
static u32 isoTOC[102];
static disc_info_struct disc;

#define MSF_TO_FAD(m,s,f) ((m * 4500) + (s * 75) + f)

//////////////////////////////////////////////////////////////////////////////

static int LoadBinCue(const char *cuefilename, FILE *iso_file)
{
   u32 size;
   char *iso_file_content, *iso_file_content_current_pos;
   size_t numcharsread = 0;
   char*temp_buffer, *temp_buffer2;
   unsigned int track_num;
   unsigned int indexnum, min, sec, frame;
   unsigned int pregap=0;
   char *p, *p2;
   track_info_struct trk[100];
   int file_size;
   int i;
   FILE * bin_file;
   int matched = 0;

   memset(trk, 0, sizeof(trk));
   disc.session_num = 1;
   disc.session = malloc(sizeof(session_info_struct) * disc.session_num);
   if (disc.session == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      return -1;
   }

   fseek(iso_file, 0, SEEK_END);
   size = ftell(iso_file);
   fseek(iso_file, 0, SEEK_SET);

   iso_file_content = malloc(size + 1);
   if (iso_file_content == NULL)
	   return -1;

   iso_file_content_current_pos = iso_file_content;
   fread(iso_file_content, size, 1, iso_file);
   iso_file_content[size] = '\0';
   fclose(iso_file);

   // Allocate buffer with enough space for reading cue
   if ((temp_buffer = (char *)calloc(size, 1)) == NULL)
      return -1;

   // Skip image filename
   if (sscanf(iso_file_content_current_pos, "FILE \"%*[^\"]\" %*s\r\n%n", &numcharsread) != 0)
   {
      free(iso_file_content);
      free(temp_buffer);
      return -1;
   }
   iso_file_content_current_pos += numcharsread;

   // Time to generate TOC
   for (;;)
   {
      // Retrieve a line in cue
      if (sscanf(iso_file_content_current_pos, "%s%n", temp_buffer, &numcharsread) != 1)
         break;
      iso_file_content_current_pos += numcharsread;

      // Figure out what it is
      if (strncmp(temp_buffer, "TRACK", 5) == 0)
      {
         // Handle accordingly
         if (sscanf(iso_file_content_current_pos, "%d %[^\r\n]\r\n%n", &track_num, temp_buffer, &numcharsread) != 2)
            break;
         iso_file_content_current_pos += numcharsread;

         if (strncmp(temp_buffer, "MODE1", 5) == 0 ||
            strncmp(temp_buffer, "MODE2", 5) == 0)
         {
            // Figure out the track sector size
            trk[track_num-1].sector_size = atoi(temp_buffer + 6);
            trk[track_num-1].ctl_addr = 0x41;
         }
         else if (strncmp(temp_buffer, "AUDIO", 5) == 0)
         {
            // Update toc entry
            trk[track_num-1].sector_size = 2352;
            trk[track_num-1].ctl_addr = 0x01;
         }
      }
      else if (strncmp(temp_buffer, "INDEX", 5) == 0)
      {
         // Handle accordingly

         if (sscanf(iso_file_content_current_pos, "%d %d:%d:%d\r\n%n", &indexnum, &min, &sec, &frame, &numcharsread) != 4)
            break;
		 iso_file_content_current_pos += numcharsread;

         if (indexnum == 1)
         {
            // Update toc entry
            trk[track_num-1].fad_start = (MSF_TO_FAD(min, sec, frame) + pregap + 150);
            trk[track_num-1].file_offset = MSF_TO_FAD(min, sec, frame) * trk[track_num-1].sector_size;
         }
      }
      else if (strncmp(temp_buffer, "PREGAP", 6) == 0)
      {
         if (sscanf(iso_file_content_current_pos, "%d:%d:%d\r\n%n", &min, &sec, &frame, &numcharsread) != 3)
            break;
		 iso_file_content_current_pos += numcharsread;

         pregap += MSF_TO_FAD(min, sec, frame);
      }
      else if (strncmp(temp_buffer, "POSTGAP", 7) == 0)
      {
         if (sscanf(iso_file_content_current_pos, "%d:%d:%d\r\n%n", &min, &sec, &frame, &numcharsread) != 3)
            break;
		 iso_file_content_current_pos += numcharsread;
      }
      else if (strncmp(temp_buffer, "FILE", 4) == 0)
      {
         YabSetError(YAB_ERR_OTHER, "Unsupported cue format");
		 free(iso_file_content);
         free(temp_buffer);
         return -1;
      }
   }

   trk[track_num].file_offset = 0;
   trk[track_num].fad_start = 0xFFFFFFFF;

   // Retrieve image filename
   matched = sscanf(iso_file_content, "FILE \"%[^\"]\" %*s\r\n", temp_buffer);
   free(iso_file_content);

   // Now go and open up the image file, figure out its size, etc.
   if ((bin_file = fopen(temp_buffer, "rb")) == NULL)
   {
      // Ok, exact path didn't work. Let's trim the path and try opening the
      // file from the same directory as the cue.

      // find the start of filename
      p = temp_buffer;

      for (;;)
      {
         if (strcspn(p, "/\\") == strlen(p))
         break;

         p += strcspn(p, "/\\") + 1;
      }

      // append directory of cue file with bin filename
      if ((temp_buffer2 = (char *)calloc(strlen(cuefilename) + strlen(p) + 1, 1)) == NULL)
      {
         free(temp_buffer);
         return -1;
      }

      // find end of path
      p2 = (char *)cuefilename;

      for (;;)
      {
         if (strcspn(p2, "/\\") == strlen(p2))
            break;
         p2 += strcspn(p2, "/\\") + 1;
      }

      // Make sure there was at least some kind of path, otherwise our
      // second check is pretty useless
      if (cuefilename == p2 && temp_buffer == p)
      {
         free(temp_buffer);
         free(temp_buffer2);
         return -1;
      }

      strncpy(temp_buffer2, cuefilename, p2 - cuefilename);
      strcat(temp_buffer2, p);

      // Let's give it another try
      bin_file = fopen(temp_buffer2, "rb");
      free(temp_buffer2);

      if (bin_file == NULL)
      {
         YabSetError(YAB_ERR_FILENOTFOUND, temp_buffer);
         free(temp_buffer);
         return -1;
      }
   }

   fseek(bin_file, 0, SEEK_END);
   file_size = ftell(bin_file);
   fseek(bin_file, 0, SEEK_SET);

   for (i = 0; i < track_num; i++)
   {
      trk[i].fad_end = trk[i+1].fad_start-1;
      trk[i].file_id = 0;
      trk[i].fp = bin_file;
      trk[i].file_size = file_size;
   }

   trk[track_num-1].fad_end = trk[track_num-1].fad_start+(file_size-trk[track_num-1].file_offset)/trk[track_num-1].sector_size;

   disc.session[0].fad_start = 150;
   disc.session[0].fad_end = trk[track_num-1].fad_end;
   disc.session[0].track_num = track_num;
   disc.session[0].track = malloc(sizeof(track_info_struct) * disc.session[0].track_num);
   if (disc.session[0].track == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      free(disc.session);
      disc.session = NULL;
      return -1;
   }

   memcpy(disc.session[0].track, trk, track_num * sizeof(track_info_struct));

   // buffer is no longer needed
   free(temp_buffer);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

int LoadMDSTracks(const char *mds_filename, FILE *iso_file, mds_session_struct *mds_session, session_info_struct *session)
{
   int i;
   int track_num=0;
   u32 fad_end;

   session->track = malloc(sizeof(track_info_struct) * mds_session->last_track);
   if (session->track == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      return -1;
   }
   memset(session->track, 0, sizeof(track_info_struct) * mds_session->last_track);

   for (i = 0; i < mds_session->total_blocks; i++)
   {
      mds_track_struct track;
      FILE *fp=NULL;
      int file_size = 0;

      fseek(iso_file, mds_session->track_blocks_offset + i * sizeof(mds_track_struct), SEEK_SET);
      if (fread(&track, 1, sizeof(mds_track_struct), iso_file) != sizeof(mds_track_struct))
      {
         YabSetError(YAB_ERR_FILEREAD, mds_filename);
         free(session->track);
         return -1;
      }

      if (track.track_num == 0xA2)
         fad_end = MSF_TO_FAD(track.m, track.s, track.f);
      if (!track.extra_offset)
         continue;

      if (track.footer_offset)
      {
         mds_footer_struct footer;
         int found_dupe=0;
         int j;

         // Make sure we haven't already opened file already
         for (j = 0; j < track_num; j++)
         {
            if (track.footer_offset == session->track[j].file_id)
            {
               found_dupe = 1;
               break;
            }
         }

         if (found_dupe)
         {
            fp = session->track[j].fp;
            file_size = session->track[j].file_size;
         }
         else
         {
            fseek(iso_file, track.footer_offset, SEEK_SET);
            if (fread(&footer, 1, sizeof(mds_footer_struct), iso_file) != sizeof(mds_footer_struct))
            {
               YabSetError(YAB_ERR_FILEREAD, mds_filename);
               free(session->track);
               return -1;
            }

            fseek(iso_file, footer.filename_offset, SEEK_SET);
            if (footer.is_widechar)
            {
               wchar_t filename[512];
               wchar_t img_filename[512];
               memset(img_filename, 0, 512 * sizeof(wchar_t));

			   if (fwscanf(iso_file, L"%512c", img_filename) != 1)
               {
                  YabSetError(YAB_ERR_FILEREAD, mds_filename);
                  free(session->track);
                  return -1;
               }

               if (wcsncmp(img_filename, L"*.", 2) == 0)
               {
                  wchar_t *ext;
                  swprintf(filename, sizeof(filename)/sizeof(wchar_t), L"%S", mds_filename);
                  ext = wcsrchr(filename, '.');
                  wcscpy(ext, img_filename+1);
               }
               else
                  wcscpy(filename, img_filename);

               fp = _wfopen(filename, L"rb");
            }
            else
            {
               char filename[512];
               char img_filename[512];
               memset(img_filename, 0, 512);
			   
               if (fgets(img_filename, 512, iso_file) == NULL)
               {
                  YabSetError(YAB_ERR_FILEREAD, mds_filename);
                  free(session->track);
                  return -1;
               }

               if (strncmp(img_filename, "*.", 2) == 0)
               {
                  char *ext;
                  strcpy(filename, mds_filename);
                  ext = strrchr(filename, '.');
                  strcpy(ext, img_filename+1);
               }
               else
                  strcpy(filename, img_filename);

               fp = fopen(filename, "rb");
            }

            if (fp == NULL)
            {
               YabSetError(YAB_ERR_FILEREAD, mds_filename);
               free(session->track);
               return -1;
            }

            fseek(fp, 0, SEEK_END);
            file_size = ftell(fp);
            fseek(fp, 0, SEEK_SET);
         }
      }

      session->track[track_num].ctl_addr = (((track.addr_ctl << 4) | (track.addr_ctl >> 4)) & 0xFF);
      session->track[track_num].fad_start = track.start_sector+150;
      if (track_num > 0)
         session->track[track_num-1].fad_end = session->track[track_num].fad_start;
      session->track[track_num].file_offset = track.start_offset;
      session->track[track_num].sector_size = track.sector_size;
      session->track[track_num].fp = fp;
      session->track[track_num].file_size = file_size;
      session->track[track_num].file_id = track.footer_offset;
      session->track[track_num].interleaved_sub = track.subchannel_mode != 0 ? 1 : 0;

      track_num++;
   }

   session->track[track_num-1].fad_end = fad_end;
   session->fad_start = session->track[0].fad_start;
   session->fad_end = fad_end;
   session->track_num = track_num;
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int LoadMDS(const char *mds_filename, FILE *iso_file)
{
   s32 i;
   mds_header_struct header;

   fseek(iso_file, 0, SEEK_SET);

   if (fread((void *)&header, 1, sizeof(mds_header_struct), iso_file) != sizeof(mds_header_struct))
   {
      YabSetError(YAB_ERR_FILEREAD, mds_filename);
      return -1;
   }
   else if (memcmp(&header.signature,  "MEDIA DESCRIPTOR", sizeof(header.signature)))
   {
      YabSetError(YAB_ERR_OTHER, "Bad MDS header");
      return -1;
   }
   else if (header.version[0] > 1)
   {
      YabSetError(YAB_ERR_OTHER, "Unsupported MDS version");
      return -1;
   }

   if (header.medium_type & 0x10)
   {
      // DVD's aren't supported, not will they ever be
      YabSetError(YAB_ERR_OTHER, "DVD's aren't supported");
      return -1;
   }

   disc.session_num = header.session_count;
   disc.session = malloc(sizeof(session_info_struct) * disc.session_num);
   if (disc.session == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      return -1;
   }

   for (i = 0; i < header.session_count; i++)
   {
      mds_session_struct session;

      fseek(iso_file, header.sessions_blocks_offset + i * sizeof(mds_session_struct), SEEK_SET);
      if (fread(&session, 1, sizeof(mds_session_struct), iso_file) != sizeof(mds_session_struct))
      {
         free(disc.session);
         YabSetError(YAB_ERR_FILEREAD, mds_filename);
         return -1;
      }

      if (LoadMDSTracks(mds_filename, iso_file, &session, &disc.session[i]) != 0)
         return -1;
   }

   fclose(iso_file);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int LoadISO(FILE *iso_file)
{
   track_info_struct *track;

   disc.session_num = 1;
   disc.session = malloc(sizeof(session_info_struct) * disc.session_num);
   if (disc.session == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      return -1;
   }

   disc.session[0].fad_start = 150;
   disc.session[0].track_num = 1;
   disc.session[0].track = malloc(sizeof(track_info_struct) * disc.session[0].track_num);
   if (disc.session[0].track == NULL)
   {
      YabSetError(YAB_ERR_MEMORYALLOC, NULL);
      free(disc.session);
      disc.session = NULL;
      return -1;
   }

	memset(disc.session[0].track, 0, sizeof(track_info_struct) * disc.session[0].track_num);

   track = disc.session[0].track;
   track->ctl_addr = 0x41;
   track->fad_start = 150;
   track->file_offset = 0;
   track->fp = iso_file;
   fseek(iso_file, 0, SEEK_END);
   track->file_size = ftell(iso_file);
   track->file_id = 0;

   if (0 == (track->file_size % 2048))
      track->sector_size = 2048;
   else if (0 == (track->file_size % 2352))
      track->sector_size = 2352;
   else
   {
      YabSetError(YAB_ERR_OTHER, "Unsupported CD image!\n");
      return -1;
   }

   disc.session[0].fad_end = track->fad_end = disc.session[0].fad_start + (track->file_size / track->sector_size);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

char* StripPreSuffixWhitespace(char* string)
{
	char* p;
	for (;;)
	{
		if (string[0] == 0 || !isspace(string[0]))
			break;
		string++;
	}

	if (strlen(string) == 0)
		return string;

	p = string+strlen(string)-1;
	for (;;)
	{
		if (p <= string || !isspace(p[0]))
		{
			p[1] = '\0';
			break;
		}
		p--;
	}

	return string;
}

//////////////////////////////////////////////////////////////////////////////

int LoadParseCCD(FILE *ccd_fp, ccd_struct *ccd)
{
	char text[60], section[CCD_MAX_SECTION], old_name[CCD_MAX_NAME] = "";
	char * start, *end, *name, *value;
	int lineno = 0, error = 0, max_size = 100;

	ccd->dict = (ccd_dict_struct *)malloc(sizeof(ccd_dict_struct)*max_size);
	if (ccd->dict == NULL) 
		return -1;

	ccd->num_dict = 0;

	// Read CCD file
	while (fgets(text, sizeof(text), ccd_fp) != NULL) 
	{
		lineno++;

		start = StripPreSuffixWhitespace(text);

		if (start[0] == '[') 
		{
			// Section
			end = strchr(start+1, ']');
			if (end == NULL) 
			{
				// ] missing from section
				error = lineno;
			}
			else
			{
				end[0] = '\0';
				memset(section, 0, sizeof(section));
				strncpy(section, start + 1, sizeof(section));
				old_name[0] = '\0';
			}
		}
		else if (start[0]) 
		{
			// Name/Value pair
			end = strchr(start, '=');
			if (end) 
			{
				end[0] = '\0';
				name = StripPreSuffixWhitespace(start);
				value = StripPreSuffixWhitespace(end + 1);

				memset(old_name, 0, sizeof(old_name));
				strncpy(old_name, name, sizeof(old_name));
				if (ccd->num_dict+1 > max_size)
				{
					max_size *= 2;
					ccd->dict = realloc(ccd->dict, sizeof(ccd_dict_struct)*max_size);
					if (ccd->dict == NULL)
					{
						free(ccd->dict);
						return -2;
					}
				}
				strcpy(ccd->dict[ccd->num_dict].section, section);
				strcpy(ccd->dict[ccd->num_dict].name, name);
				strcpy(ccd->dict[ccd->num_dict].value, value);
				ccd->num_dict++;
			}
			else
				error = lineno;
		}

		if (error)
			break;
	}

	if (error)
	{
		free(ccd->dict);
		ccd->num_dict = 0;
	}

	return error;
}

//////////////////////////////////////////////////////////////////////////////

static int GetIntCCD(ccd_struct *ccd, char *section, char *name)
{
	int i;
	for (i = 0; i < ccd->num_dict; i++)
	{
		if (stricmp(ccd->dict[i].section, section) == 0 &&
			 stricmp(ccd->dict[i].name, name) == 0)
			return strtol(ccd->dict[i].value, NULL, 0);
	}

	return -1;
}

//////////////////////////////////////////////////////////////////////////////

static int LoadCCD(const char *ccd_filename, FILE *iso_file)
{
	int i;
	ccd_struct ccd;
	int num_toc;
	char img_filename[512];
	char *ext;
	FILE *fp;

	strcpy(img_filename, ccd_filename);
	ext = strrchr(img_filename, '.');
	strcpy(ext, ".img");
	fp = fopen(img_filename, "rb");

	if (fp == NULL)
	{
		YabSetError(YAB_ERR_FILEREAD, img_filename);
		return -1;
	}

	fseek(iso_file, 0, SEEK_SET);

	// Load CCD file as dictionary
	if (LoadParseCCD(iso_file, &ccd))
	{
		fclose(fp);
		YabSetError(YAB_ERR_FILEREAD, ccd_filename);
		return -1;
	}

	num_toc = GetIntCCD(&ccd, "DISC", "TocEntries");
	disc.session_num = GetIntCCD(&ccd, "DISC", "Sessions");
	if (disc.session_num != 1)
	{
		fclose(fp);
		YabSetError(YAB_ERR_OTHER, "Sessions more than 1 are unsupported");
		return -1;
	}

	disc.session = malloc(sizeof(session_info_struct) * disc.session_num);
	if (disc.session == NULL)
	{
		fclose(fp);
		free(ccd.dict);
		YabSetError(YAB_ERR_MEMORYALLOC, NULL);
		return -1;
	}

	if (GetIntCCD(&ccd, "DISC", "DataTracksScrambled"))
	{
		fclose(fp);
		free(ccd.dict);
		free(disc.session);
		YabSetError(YAB_ERR_OTHER, "CCD Scrambled Tracks not supported");
		return -1;
	}

	// Find track number and allocate
	for (i = 0; i < num_toc; i++)
	{
		char sect_name[64];
		int point;

		sprintf(sect_name, "Entry %d", i);
		point = GetIntCCD(&ccd, sect_name, "Point");

		if (point == 0xA1)
		{
			int ses = GetIntCCD(&ccd, sect_name, "Session");

			disc.session[ses-1].fad_start = 150;
			disc.session[ses-1].track_num=GetIntCCD(&ccd, sect_name, "PMin");;
			disc.session[ses-1].track = (track_info_struct *)malloc(disc.session[ses-1].track_num * sizeof(track_info_struct));
			if (disc.session[ses-1].track == NULL)
			{
				fclose(fp);
				free(ccd.dict);
				free(disc.session);
				YabSetError(YAB_ERR_MEMORYALLOC, NULL);
				return -1;
			}
			memset(disc.session[ses-1].track, 0, disc.session[ses-1].track_num * sizeof(track_info_struct));
		}
	}

	// Load TOC
	for (i = 0; i < num_toc; i++)
	{
		char sect_name[64];
		int ses, point, adr, control, trackno, amin, asec, aframe;
		int alba, zero, pmin, psec, pframe, plba;

		sprintf(sect_name, "Entry %d", i);

		ses = GetIntCCD(&ccd, sect_name, "Session");
		point = GetIntCCD(&ccd, sect_name, "Point");
		adr = GetIntCCD(&ccd, sect_name, "ADR");
		control = GetIntCCD(&ccd, sect_name, "Control");
		trackno = GetIntCCD(&ccd, sect_name, "TrackNo");
		amin = GetIntCCD(&ccd, sect_name, "AMin");
		asec = GetIntCCD(&ccd, sect_name, "ASec");
		aframe = GetIntCCD(&ccd, sect_name, "AFrame");
		alba = GetIntCCD(&ccd, sect_name, "ALBA");
		zero = GetIntCCD(&ccd, sect_name, "Zero");
		pmin = GetIntCCD(&ccd, sect_name, "PMin");
		psec = GetIntCCD(&ccd, sect_name, "PSec");
		pframe = GetIntCCD(&ccd, sect_name, "PFrame");
		plba = GetIntCCD(&ccd, sect_name, "PLBA");

		if(point >= 1 && point <= 99)
		{
			track_info_struct *track=&disc.session[ses-1].track[point-1];
			track->ctl_addr = (control << 4) | adr;
			track->fad_start = MSF_TO_FAD(pmin, psec, pframe);
			if (point >= 2)
			   disc.session[ses-1].track[point-2].fad_end = track->fad_start-1;
			track->file_offset = plba*2352;
			track->sector_size = 2352;
			track->fp = fp;
			track->file_size = (track->fad_end+1-track->fad_start)*2352;
			track->file_id = 0;
			track->interleaved_sub = 0;
		}
		else if (point == 0xA2)
		{
			disc.session[ses-1].fad_end = MSF_TO_FAD(pmin, psec, pframe);
			disc.session[ses-1].track[disc.session[ses-1].track_num-1].fad_end = disc.session[ses-1].fad_end;
		}
	}

	fclose(iso_file);

	return 0;
}

//////////////////////////////////////////////////////////////////////////////

void BuildTOC()
{
   int i;
   session_info_struct *session=&disc.session[0];

   for (i = 0; i < session->track_num; i++)
   {
      track_info_struct *track=&disc.session[0].track[i];
      isoTOC[i] = (track->ctl_addr << 24) | track->fad_start;
   }

   isoTOC[99] = (isoTOC[0] & 0xFF000000) | 0x010000;
   isoTOC[100] = (isoTOC[session->track_num - 1] & 0xFF000000) | (session->track_num << 16);
   isoTOC[101] = (isoTOC[session->track_num - 1] & 0xFF000000) | session->fad_end;
}

//////////////////////////////////////////////////////////////////////////////

static int ISOCDInit(const char * iso) {
   char header[6];
   char *ext;
   int ret;
   FILE *iso_file;
   size_t num_read = 0;

   memset(isoTOC, 0xFF, 0xCC * 2);
   memset(&disc, 0, sizeof(disc));

   if (!iso)
      return -1;

   if (!(iso_file = fopen(iso, "rb")))
   {
      YabSetError(YAB_ERR_FILENOTFOUND, (char *)iso);
      return -1;
   }

   num_read = fread((void *)header, 1, 6, iso_file);
   ext = strrchr(iso, '.');

   // Figure out what kind of image format we're dealing with
   if (stricmp(ext, ".CUE") == 0 && strncmp(header, "FILE \"", 6) == 0)
   {
      // It's a BIN/CUE
      imgtype = IMG_BINCUE;
      ret = LoadBinCue(iso, iso_file);
   }
   else if (stricmp(ext, ".MDS") == 0 && strncmp(header, "MEDIA ", sizeof(header)) == 0)
   {
      // It's a MDS
      imgtype = IMG_MDS;
      ret = LoadMDS(iso, iso_file);
   }
	else if (stricmp(ext, ".CCD") == 0)
	{
		// It's a CCD
		imgtype = IMG_CCD;
		ret = LoadCCD(iso, iso_file);
	}
   else
   {
      // Assume it's an ISO file
      imgtype = IMG_ISO;
      ret = LoadISO(iso_file);
   }

   if (ret != 0)
   {
      imgtype = IMG_NONE;

      if (iso_file)
         fclose(iso_file);
      iso_file = NULL;
      return -1;
   }   

   BuildTOC();
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void ISOCDDeInit(void) {
   int i, j, k;
   if (disc.session)
   {
      for (i = 0; i < disc.session_num; i++)
      {
         if (disc.session[i].track)
         {
            for (j = 0; j < disc.session[i].track_num; j++)
            {
               if (disc.session[i].track[j].fp)
               {
                  fclose(disc.session[i].track[j].fp);

                  // Make sure we don't close the same file twice
                  for (k = j+1; k < disc.session[i].track_num; k++)
                  {
                     if (disc.session[i].track[j].file_id == disc.session[i].track[k].file_id)
                        disc.session[i].track[k].fp = NULL;
                  }
               }
            }
            free(disc.session[i].track);
         }
      }
      free(disc.session);
   }
}

//////////////////////////////////////////////////////////////////////////////

static int ISOCDGetStatus(void) {
   return disc.session_num > 0 ? 0 : 2;
}

//////////////////////////////////////////////////////////////////////////////

static s32 ISOCDReadTOC(u32 * TOC) {
   memcpy(TOC, isoTOC, 0xCC * 2);

   return (0xCC * 2);
}

//////////////////////////////////////////////////////////////////////////////

static int ISOCDReadSectorFAD(u32 FAD, void *buffer) {
   int i,j;
   size_t num_read = 0;
   track_info_struct *track=NULL;

   assert(disc.session);

   memset(buffer, 0, 2448);

   for (i = 0; i < disc.session_num; i++)
   {
      for (j = 0; j < disc.session[i].track_num; j++)
      {
         if (FAD >= disc.session[i].track[j].fad_start &&
             FAD <= disc.session[i].track[j].fad_end)
         {             
            track = &disc.session[i].track[j];
            break;
         }
      }
   }

   if (track == NULL)
   {
      CDLOG("Warning: Sector not found in track list");
      return 0;
   }

   fseek(track->fp, track->file_offset + (FAD-track->fad_start) * track->sector_size, SEEK_SET);
	if (track->sub_fp)
		fseek(track->sub_fp, track->file_offset + (FAD-track->fad_start) * 96, SEEK_SET);
   if (track->sector_size == 2448)
   {
      if (!track->interleaved_sub)
		{
			if (track->sub_fp)
			{
            num_read = fread(buffer, 2352, 1, track->fp);
            num_read = fread((char *)buffer + 2352, 96, 1, track->sub_fp);
			}
			else
            num_read = fread(buffer, 2448, 1, track->fp);
		}
      else
      {
         const u16 deint_offsets[] = {
            0, 66, 125, 191, 100, 50, 150, 175, 8, 33, 58, 83, 
            108, 133, 158, 183, 16, 41, 25, 91, 116, 141, 166, 75, 
            24, 90, 149, 215, 124, 74, 174, 199, 32, 57, 82, 107, 
            132, 157, 182, 207, 40, 65, 49, 115, 140, 165, 190, 99, 
            48, 114, 173, 239, 148, 98, 198, 223, 56, 81, 106, 131, 
            156, 181, 206, 231, 64, 89, 73, 139, 164, 189, 214, 123, 
            72, 138, 197, 263, 172, 122, 222, 247, 80, 105, 130, 155, 
            180, 205, 230, 255, 88, 113, 97, 163, 188, 213, 238, 147
         };
         u8 subcode_buffer[96 * 3];

         num_read = fread(buffer, 2352, 1, track->fp);

         num_read = fread(subcode_buffer, 96, 1, track->fp);
         fseek(track->fp, 2352, SEEK_CUR);
         num_read = fread(subcode_buffer + 96, 96, 1, track->fp);
         fseek(track->fp, 2352, SEEK_CUR);
         num_read = fread(subcode_buffer + 192, 96, 1, track->fp);
         for (i = 0; i < 96; i++)
            ((u8 *)buffer)[2352+i] = subcode_buffer[deint_offsets[i]];
      }
   }
   else if (track->sector_size == 2352)
   {
      // Generate subcodes here
      num_read = fread(buffer, 2352, 1, track->fp);
   }
   else if (track->sector_size == 2048)
   {
      memcpy(buffer, syncHdr, 12);
      num_read = fread((char *)buffer + 0x10, 2048, 1, track->fp);
   }
	return 1;
}

//////////////////////////////////////////////////////////////////////////////

static void ISOCDReadAheadFAD(UNUSED u32 FAD)
{
	// No-op
}

//////////////////////////////////////////////////////////////////////////////
