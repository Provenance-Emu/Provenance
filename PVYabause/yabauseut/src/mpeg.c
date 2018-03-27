/*  Copyright 2013 Theo Berkau

    This file is part of YabauseUT

    YabauseUT is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    YabauseUT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with YabauseUT; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <iapetus.h>
#include "tests.h"
#include "cdb.h"
#include "mpeg.h"

file_struct mpeg_file;

#define CDWORKBUF ((void *)0x202C0000)

void mpeg_test()
{
   int choice;

   menu_item_struct mpeg_menu[] = {
      { "MPEG Commands", &mpeg_cmd_test, },
      { "MPEG Play", &mpeg_play_test, },
      { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(mpeg_menu, &test_disp_font, 0, 0, "MPEG Card Tests", MTYPE_CENTER, -1);
      gui_clear_scr(&test_disp_font);
      if (choice == -1)
         break;
   }   
}

//////////////////////////////////////////////////////////////////////////////

void mpeg_cmd_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void mpeg_play_test()
{
   init_cdb_tests();

   unregister_all_tests();

   register_test(&test_mpegplay_init, "MPEG Init");
   register_test(&test_mpegplay_play, "MPEG Play");
   register_test(&test_mpegplay_pause, "MPEG Pause");
   register_test(&test_mpegplay_unpause, "MPEG Unpause");
   register_test(&test_mpegplay_stop, "MPEG Stop");
   do_tests("MPEG Play tests", 0, 0);

   vdp_exbg_deinit();
}

//////////////////////////////////////////////////////////////////////////////

void test_mpegplay_init()
{
   int ret;

   test_disp_font.transparent = 0;

   if ((ret = mpeg_init()) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
   }
   else
      stage_status = STAGESTAT_DONE;

   test_disp_font.transparent = 1;
}

//////////////////////////////////////////////////////////////////////////////

BOOL test_mpeg_status(test_mpeg_status_struct *settings)
{
   u32 freq;
   mpeg_status_struct mpeg_status;
   u16 old_v_counter;

   timer_setup(TIMER_HBLANK, &freq);
   timer_delay(freq, settings->delay);

   if (mpeg_get_status(&mpeg_status) != IAPETUS_ERR_OK)
      return FALSE;

   if (mpeg_status.play_status != (MS_PS_VIDEO_PLAYING | MS_PS_AUDIO_PLAYING) &&
      mpeg_status.mpeg_audio_status != (MS_AS_DECODE_OP | MS_AS_LEFT_OUTPUT | MS_AS_RIGHT_OUTPUT) &&
      (mpeg_status.mpeg_video_status & 0xF) != (MS_VS_DECODE_OP | MS_VS_DISPLAYING))
      return FALSE;

   // Verify that the v_counter is incrementing
   old_v_counter = mpeg_status.v_counter;
   vdp_vsync();

   if (mpeg_get_status(&mpeg_status) != IAPETUS_ERR_OK)
      return FALSE;

   if (old_v_counter+1 != mpeg_status.v_counter)
      return FALSE;

   return TRUE;
}

void test_mpegplay_play()
{
   int ret;
   test_mpeg_status_struct tms_settings;

   test_disp_font.transparent = 0;

   if ((ret = cdfs_init(CDWORKBUF, 4096)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   if ((ret = cdfs_open("AN000.MPG", &mpeg_file)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   if ((ret = mpeg_play(&mpeg_file)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   tms_settings.delay = 2000;
   tms_settings.play_status = (MS_PS_VIDEO_PLAYING | MS_PS_AUDIO_PLAYING);
   tms_settings.play_status = 0xFF;
   tms_settings.mpeg_audio_status = (MS_AS_DECODE_OP | MS_AS_LEFT_OUTPUT | MS_AS_RIGHT_OUTPUT);
   tms_settings.mpeg_audio_status = 0xFF;
   tms_settings.mpeg_video_status = (MS_VS_DECODE_OP | MS_VS_DISPLAYING);
   tms_settings.mpeg_video_status = 0x000F;
   tms_settings.v_counter_inc = TRUE;

   if (!test_mpeg_status(&tms_settings))
   {
      tests_disp_iapetus_error(IAPETUS_ERR_UNEXPECTDATA, __FILE__, __LINE__);
      mpeg_stop(&mpeg_file);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   test_disp_font.transparent = 1;
   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void test_mpegplay_pause()
{
   int ret;
   test_mpeg_status_struct tms_settings;

   if ((ret = mpeg_pause(&mpeg_file)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   tms_settings.delay = 2000;
   tms_settings.play_status = (MS_PS_VIDEO_PLAYING | MS_PS_AUDIO_PLAYING);
   tms_settings.play_status = 0xFF;
   tms_settings.mpeg_audio_status = (MS_AS_DECODE_OP | MS_AS_LEFT_OUTPUT | MS_AS_RIGHT_OUTPUT);
   tms_settings.mpeg_audio_status = 0xFF;
   tms_settings.mpeg_video_status = (MS_VS_DECODE_OP | MS_VS_DISPLAYING | MS_VS_PAUSED);
   tms_settings.mpeg_video_status = 0x000F;
   tms_settings.v_counter_inc = TRUE;

   if (!test_mpeg_status(&tms_settings))
   {
      tests_disp_iapetus_error(IAPETUS_ERR_UNEXPECTDATA, __FILE__, __LINE__);
      mpeg_stop(&mpeg_file);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void test_mpegplay_unpause()
{
   int ret;
   test_mpeg_status_struct tms_settings;

   if ((ret = mpeg_unpause(&mpeg_file)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   tms_settings.delay = 2000;
   tms_settings.play_status = (MS_PS_VIDEO_PLAYING | MS_PS_AUDIO_PLAYING);
   tms_settings.play_status = 0xFF;
   tms_settings.mpeg_audio_status = (MS_AS_DECODE_OP | MS_AS_LEFT_OUTPUT | MS_AS_RIGHT_OUTPUT);
   tms_settings.mpeg_audio_status = 0xFF;
   tms_settings.mpeg_video_status = (MS_VS_DECODE_OP | MS_VS_DISPLAYING);
   tms_settings.mpeg_video_status = 0x000F;
   tms_settings.v_counter_inc = TRUE;

   if (!test_mpeg_status(&tms_settings))
   {
      tests_disp_iapetus_error(IAPETUS_ERR_UNEXPECTDATA, __FILE__, __LINE__);
      mpeg_stop(&mpeg_file);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////

void test_mpegplay_stop()
{
   int ret;
   test_mpeg_status_struct tms_settings;

   if ((ret = mpeg_stop(&mpeg_file)) != IAPETUS_ERR_OK)
   {
      tests_disp_iapetus_error(ret, __FILE__, __LINE__);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   tms_settings.delay = 2000;
   tms_settings.play_status = (MS_PS_VIDEO_RECEIVING | MS_PS_AUDIO_RECEIVING);
   tms_settings.play_status = 0xFF;
   tms_settings.mpeg_audio_status = (MS_AS_DECODE_OP | MS_AS_BUFFER_EMPTY | MS_AS_LEFT_OUTPUT | MS_AS_RIGHT_OUTPUT);
   tms_settings.mpeg_audio_status = 0xFF;
   tms_settings.mpeg_video_status = (MS_VS_DECODE_OP | MS_VS_DISPLAYING | MS_VS_PAUSED);
   tms_settings.mpeg_video_status = 0x000F;

   if (!test_mpeg_status(&tms_settings))
   {
      tests_disp_iapetus_error(IAPETUS_ERR_UNEXPECTDATA, __FILE__, __LINE__);
      mpeg_stop(&mpeg_file);
      stage_status = STAGESTAT_BADDATA;
      return;
   }

   stage_status = STAGESTAT_DONE;
}

//////////////////////////////////////////////////////////////////////////////
