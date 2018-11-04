#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "deps/coreio/coreio.h"
#include "cdipsr.h"

// Global variables

unsigned long temp_value;


/////////////////////////////////////////////////////////////////////////////

#define FILE core_file
#define fread(buff,sz,cnt,fc) core_fread(fc,buff,sz*cnt)
#define fseek core_fseek
#define ftell core_ftell

unsigned long ask_type(FILE *fsource, long header_position)
{

unsigned char filename_length;
unsigned long track_mode;

    fseek(fsource, header_position, SEEK_SET);
    fread(&temp_value, 4, 1, fsource);
    if (temp_value != 0)
       fseek(fsource, 8, SEEK_CUR); // extra data (DJ 3.00.780 and up)
    fseek(fsource, 24, SEEK_CUR);
    fread(&filename_length, 1, 1, fsource);
    fseek(fsource, filename_length, SEEK_CUR);
    fseek(fsource, 19, SEEK_CUR);
    fread(&temp_value, 4, 1, fsource);
       if (temp_value == 0x80000000)
          fseek(fsource, 8, SEEK_CUR); // DJ4
    fseek(fsource, 16, SEEK_CUR);
    fread(&track_mode, 4, 1, fsource);
    fseek(fsource, header_position, SEEK_SET);
    return (track_mode);
}


/////////////////////////////////////////////////////////////////////////////


void CDI_read_track (FILE *fsource, image_s *image, track_s *track)
{

     unsigned char TRACK_START_MARK[10] = { 0, 0, 0x01, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF };
     unsigned char current_start_mark[10];

         fread(&temp_value, 4, 1, fsource);
         if (temp_value != 0)
            fseek(fsource, 8, SEEK_CUR); // extra data (DJ 3.00.780 and up)

         fread(&current_start_mark, 10, 1, fsource);
         if (memcmp(TRACK_START_MARK, current_start_mark, 10)) printf( "Unsupported format: Could not find the track start mark");

         fread(&current_start_mark, 10, 1, fsource);
         if (memcmp(TRACK_START_MARK, current_start_mark, 10)) printf(  "Unsupported format: Could not find the track start mark");

         fseek(fsource, 4, SEEK_CUR);
         fread(&track->filename_length, 1, 1, fsource);
         fseek(fsource, track->filename_length, SEEK_CUR);
         fseek(fsource, 11, SEEK_CUR);
         fseek(fsource, 4, SEEK_CUR);
         fseek(fsource, 4, SEEK_CUR);
         fread(&temp_value, 4, 1, fsource);
            if (temp_value == 0x80000000)
               fseek(fsource, 8, SEEK_CUR); // DJ4
         fseek(fsource, 2, SEEK_CUR);
         fread(&track->pregap_length, 4, 1, fsource);
         fread(&track->length, 4, 1, fsource);
         fseek(fsource, 6, SEEK_CUR);
         fread(&track->mode, 4, 1, fsource);
         fseek(fsource, 12, SEEK_CUR);
         fread(&track->start_lba, 4, 1, fsource);
         fread(&track->total_length, 4, 1, fsource);
         fseek(fsource, 16, SEEK_CUR);
         fread(&track->sector_size_value, 4, 1, fsource);

         switch(track->sector_size_value)
               {
               case 0 : track->sector_size = 2048; break;
               case 1 : track->sector_size = 2336; break;
               case 2 : track->sector_size = 2352; break;
               default: printf("Unsupported sector size");
               }

         if (track->mode > 2) printf( "Unsupported format: Track mode not supported");

         fseek(fsource, 29, SEEK_CUR);
         if (image->version != CDI_V2)
            {
            fseek(fsource, 5, SEEK_CUR);
            fread(&temp_value, 4, 1, fsource);
            if (temp_value == 0xffffffff)
                fseek(fsource, 78, SEEK_CUR); // extra data (DJ 3.00.780 and up)
            }
}


void CDI_skip_next_session (FILE *fsource, image_s *image)
{
     fseek(fsource, 4, SEEK_CUR);
     fseek(fsource, 8, SEEK_CUR);
     if (image->version != CDI_V2) fseek(fsource, 1, SEEK_CUR);
}

void CDI_get_tracks (FILE *fsource, image_s *image)
{
     fread(&image->tracks, 2, 1, fsource);
}

void CDI_init (FILE *fsource, image_s *image, char *fsourcename)
{
	image->length = core_fsize(fsource);

     if (image->length < 8) printf( "Image file is too short");

     fseek(fsource, image->length-8, SEEK_SET);
     fread(&image->version, 4, 1, fsource);
     fread(&image->header_offset, 4, 1, fsource);

   //  if (errno != 0) printf( fsourcename);
     if (image->header_offset == 0) printf( "Bad image format");
}

void CDI_get_sessions (FILE *fsource, image_s *image)
{
#ifndef DEBUG_CDI
     if (image->version == CDI_V35)
        fseek(fsource, (image->length - image->header_offset), SEEK_SET);
     else
        fseek(fsource, image->header_offset, SEEK_SET);

#else
     fseek(fsource, 0L, SEEK_SET);
#endif
     fread(&image->sessions, 2, 1, fsource);
}

