/*  Copyright 2006 Guillaume Duhamel
    Copyright 2006 Fabien Coulon
    Copyright 2005 Joost Peters

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

#include "gtkglwidget.h"
#include "yuiwindow.h"

#include "../yabause.h"
#include "../yui.h"
#include "../peripheral.h"
#include "../sh2core.h"
#include "../sh2int.h"
#include "../vidogl.h"
#include "../vidsoft.h"
#include "../cs0.h"
#include "../cs2.h"
#include "../cdbase.h"
#include "../scsp.h"
#include "../sndsdl.h"
#include "../sndal.h"
#include "../persdljoy.h"
#ifdef ARCH_IS_LINUX
#include "../perlinuxjoy.h"
#endif
#include "../debug.h"
#include "../m68kcore.h"
#include "../m68kc68k.h"
#include "pergtk.h"

#include "settings.h"

static char biospath[256] = "\0";
static char cdpath[256] = "\0";
static char buppath[256] = "\0";
static char mpegpath[256] = "\0";
static char cartpath[256] = "\0";

M68K_struct * M68KCoreList[] = {
&M68KDummy,
#ifdef HAVE_C68K
&M68KC68K,
#endif
#ifdef HAVE_Q68
&M68KQ68,
#endif
NULL
};

SH2Interface_struct *SH2CoreList[] = {
&SH2Interpreter,
&SH2DebugInterpreter,
#ifdef TEST_PSP_SH2
&SH2PSP,
#endif
#ifdef SH2_DYNAREC
&SH2Dynarec,
#endif
NULL
};

PerInterface_struct *PERCoreList[] = {
&PERDummy,
&PERGTK,
#ifdef HAVE_LIBSDL
&PERSDLJoy,
#endif
#ifdef ARCH_IS_LINUX
&PERLinuxJoy,
#endif
NULL
};

CDInterface *CDCoreList[] = {
&DummyCD,
&ISOCD,
#ifndef UNKNOWN_ARCH
&ArchCD,
#endif
NULL
};

SoundInterface_struct *SNDCoreList[] = {
&SNDDummy,
#ifdef HAVE_LIBSDL
&SNDSDL,
#endif
#ifdef HAVE_LIBAL
&SNDAL,
#endif
NULL
};

VideoInterface_struct *VIDCoreList[] = {
&VIDDummy,
#ifdef HAVE_LIBGTKGLEXT
&VIDOGL,
#endif
&VIDSoft,
NULL
};

#ifdef YAB_PORT_OSD
OSD_struct *OSDCoreList[] = {
&OSDDummy,
#ifdef HAVE_LIBGLUT
&OSDGlut,
#endif
&OSDSoft,
NULL
};
#endif

GtkWidget * yui;
GKeyFile * keyfile;
yabauseinit_struct yinit;

static int yui_main(gpointer data) {
	PERCore->HandleEvents();
	return TRUE;
}

static GtkWidget * yui_new(void) {
	yui = yui_window_new(NULL, G_CALLBACK(YabauseInit), &yinit, yui_main, G_CALLBACK(YabauseReset));

	gtk_widget_show(yui);

	return yui;
}

static void yui_settings_init(void) {
	yinit.m68kcoretype = M68KCORE_C68K;
	yinit.percoretype = PERCORE_GTK;
	yinit.sh2coretype = SH2CORE_DEFAULT;
#ifdef HAVE_LIBGTKGLEXT
	yinit.vidcoretype = VIDCORE_OGL;
#else
	yinit.vidcoretype = VIDCORE_SOFT;
#endif
	yinit.sndcoretype = SNDCORE_DUMMY;
	yinit.cdcoretype = CDCORE_DEFAULT;
	yinit.carttype = CART_NONE;
	yinit.regionid = 0;
	yinit.biospath = biospath;
	yinit.cdpath = cdpath;
	yinit.buppath = buppath;
	yinit.mpegpath = mpegpath;
	yinit.cartpath = cartpath;
        yinit.videoformattype = VIDEOFORMATTYPE_NTSC;
	yinit.osdcoretype = OSDCORE_DEFAULT;
}

gchar * inifile;

static int safe_strcmp(const char * s1, const char * s2) {
	if (s1) {
		if (s2) {
			return strcmp(s1, s2);
		} else {
			return 1;
		}
	} else {
		if (s2) {
			return -1;
		} else {
			return 0;
		}
	}
}

extern void * padbits;
void * padbits;

static gboolean yui_settings_load(void) {
	int i, tmp;
	long tmptime;
	gchar * stmp;
	gboolean mustRestart = FALSE;

	g_key_file_load_from_file(keyfile, inifile, G_KEY_FILE_NONE, 0);

	/* bios */
	stmp = g_key_file_get_value(keyfile, "General", "BiosPath", 0);
	if (stmp && !*stmp) stmp = NULL;
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && safe_strcmp(stmp, yinit.biospath)) {
		mustRestart = TRUE;
	}
	if (stmp) {
		g_strlcpy(biospath, stmp, 256);
		yinit.biospath = biospath;
	}
	else yinit.biospath = NULL;

	/* cd core */
	stmp = g_key_file_get_value(keyfile, "General", "CDROMDrive", 0);
	if (stmp && !*stmp) stmp = NULL;
	if((YUI_WINDOW(yui)->state & YUI_IS_INIT) && safe_strcmp(stmp, yinit.cdpath)) {
		Cs2ChangeCDCore(yinit.cdcoretype, stmp);
	}
	if (stmp) g_strlcpy(cdpath, stmp, 256);

	tmp = yinit.cdcoretype;
	yinit.cdcoretype = g_key_file_get_integer(keyfile, "General", "CDROMCore", 0);
	if((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.cdcoretype)) {
		Cs2ChangeCDCore(yinit.cdcoretype, yinit.cdpath);
	}

	/* region */
	{
		char * region = g_key_file_get_value(keyfile, "General", "Region", 0);
		tmp = yinit.regionid;
		if ((region == 0) || !strcmp(region, "Auto")) {
			yinit.regionid = 0;
		} else {
			switch(region[0]) {
				case 'J': yinit.regionid = 1; break;
				case 'T': yinit.regionid = 2; break;
				case 'U': yinit.regionid = 4; break;
				case 'B': yinit.regionid = 5; break;
				case 'K': yinit.regionid = 6; break;
				case 'A': yinit.regionid = 0xA; break;
				case 'E': yinit.regionid = 0xC; break;
				case 'L': yinit.regionid = 0xD; break;
			}
		}

		if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.regionid)) {
			mustRestart = TRUE;
		}
	}

	/* cart */
	stmp = g_key_file_get_value(keyfile, "General", "CartPath", 0);
	if (stmp && !*stmp) stmp = NULL;
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && safe_strcmp(stmp, yinit.cartpath)) {
		mustRestart = TRUE;
	}
	if (stmp) {
		g_strlcpy(cartpath, stmp, 256);
		yinit.cartpath = cartpath;
	}
	else yinit.cartpath = NULL;

	tmp = yinit.carttype;
	yinit.carttype = g_key_file_get_integer(keyfile, "General", "CartType", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.carttype)) {
          mustRestart = TRUE;
	}

	/* backup ram */
	stmp = g_key_file_get_value(keyfile, "General", "BackupRamPath", 0);
	if (stmp && !*stmp) stmp = NULL;
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && safe_strcmp(stmp, yinit.buppath)) {
		mustRestart = TRUE;
	}
	if (stmp) {
		g_strlcpy(buppath, stmp, 256);
		yinit.buppath = buppath;
	}
	else yinit.buppath = NULL;

	/* mpeg rom */
	stmp = g_key_file_get_value(keyfile, "General", "MpegRomPath", 0);
	if (stmp && !*stmp) stmp = NULL;
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && safe_strcmp(stmp, yinit.mpegpath)) {
		mustRestart = TRUE;
	}
	if (stmp) {
		g_strlcpy(mpegpath, stmp, 256);
		yinit.mpegpath = mpegpath;
	}
	else yinit.mpegpath = NULL;

	/* sh2 */
	tmp = yinit.sh2coretype;
	yinit.sh2coretype = g_key_file_get_integer(keyfile, "General", "SH2Int", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.sh2coretype)) {
		mustRestart = TRUE;
	}

	/* m68k */
	tmp = yinit.m68kcoretype;
	yinit.m68kcoretype = g_key_file_get_integer(keyfile, "General", "M68kInt", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.m68kcoretype)) {
		mustRestart = TRUE;
	}

	/* video core */
	tmp = yinit.vidcoretype;
	yinit.vidcoretype = g_key_file_get_integer(keyfile, "General", "VideoCore", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.vidcoretype)) {
		VideoChangeCore(yinit.vidcoretype);
		VIDCore->Resize(
			GTK_WIDGET(YUI_WINDOW(yui)->area)->allocation.width,
			GTK_WIDGET(YUI_WINDOW(yui)->area)->allocation.height,
			FALSE);
	}

	/* osd core */
	tmp = yinit.osdcoretype;
	yinit.osdcoretype = g_key_file_get_integer(keyfile, "General", "OSDCore", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.osdcoretype)) {
		OSDChangeCore(yinit.osdcoretype);
	}

	/* sound core */
	tmp = yinit.sndcoretype;
	yinit.sndcoretype = g_key_file_get_integer(keyfile, "General", "SoundCore", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.sndcoretype)) {
		ScspChangeSoundCore(yinit.sndcoretype);
	}

	ScspSetVolume(g_key_file_get_integer(keyfile, "General", "Volume", NULL));

	/* peripheral core */
	yinit.percoretype = g_key_file_get_integer(keyfile, "General", "PerCore", 0);

	/* audio sync */
	tmp = g_key_file_get_boolean(keyfile, "General", "AudioSync", 0);
	ScspSetFrameAccurate(tmp);

	/* clock sync */
	tmp = yinit.clocksync;
	yinit.clocksync = g_key_file_get_boolean(keyfile, "General", "ClockSync", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.clocksync)) {
		mustRestart = TRUE;
	}
	tmptime = yinit.basetime;
	tmp = g_key_file_get_boolean(keyfile, "General", "FixedBaseTime", 0);
	if (tmp && yinit.clocksync) {
		/* Find timestamp of 1998-01-01 12:00 in the local time zone */
		time_t utc = 883656000;  // 1998-01-01 12:00 UTC
		struct tm tm;
		long local, noon;
		localtime_r(&utc, &tm);
		local = tm.tm_hour*3600 + tm.tm_min*60 + tm.tm_sec;
		if (tm.tm_mday == 2)  // 1998-01-02
			local += 86400;
		else if (tm.tm_mday == 31)  // 1997-12-31
			local -= 86400;
		noon = 12*3600 + 0*60 + 0;
		yinit.basetime = (long)utc + (noon - local);
	} else {
		yinit.basetime = 0;
	}
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmptime != yinit.basetime)) {
		mustRestart = TRUE;
	}

	/* threads */
	tmp = g_key_file_get_boolean(keyfile, "General", "UseThreads", 0);
	if ((YUI_WINDOW(yui)->state & YUI_IS_INIT) && (tmp != yinit.usethreads)) {
		mustRestart = TRUE;
	}
	yinit.usethreads = tmp;

	PerInit(yinit.percoretype);

	PerPortReset();
	switch(g_key_file_get_integer(keyfile, "General", "PerType", NULL))
	{
		case PERMOUSE:
			padbits = PerMouseAdd(&PORTDATA1);
			i = 0;

			while(PerMouseNames[i]) {
				char tmp[100];
				u32 key;
				sprintf(tmp, "Mouse.%s.1", PerMouseNames[i]);
	  			key = g_key_file_get_integer(keyfile, PERCore->Name, tmp, 0);
		  		PerSetKey(key, i + 13, padbits);
		  		i++;
			}
			break;
		case PERPAD:
		default:
			padbits = PerPadAdd(&PORTDATA1);
			i = 0;

			while(PerPadNames[i]) {
				char tmp[100];
				u32 key;
				sprintf(tmp, "Pad.%s.1", PerPadNames[i]);
	  			key = g_key_file_get_integer(keyfile, PERCore->Name, tmp, 0);
		  		PerSetKey(key, i, padbits);
		  		i++;
			}
	}

	yui_resize(g_key_file_get_integer(keyfile, "General", "Width", 0),
			g_key_file_get_integer(keyfile, "General", "Height", 0),
			g_key_file_get_integer(keyfile, "General", "Fullscreen", 0));

        yinit.videoformattype = g_key_file_get_integer(keyfile, "General", "VideoFormat", 0);

	yui_window_set_frameskip(YUI_WINDOW(yui), g_key_file_get_integer(keyfile, "General", "Frameskip", NULL));

	return mustRestart;
}

void YuiErrorMsg(const char * string) {
	GtkWidget* warningDlg = gtk_message_dialog_new (GTK_WINDOW(yui), GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR,
                               	                        GTK_BUTTONS_OK, string, NULL);
       	gtk_dialog_run (GTK_DIALOG(warningDlg));
       	gtk_widget_destroy (warningDlg); 
}

int main(int argc, char *argv[]) {
#ifndef NO_CLI
	int i;
#endif
	LogStart();
	LogChangeOutput( DEBUG_STDERR, NULL );
	inifile = g_build_filename(g_get_user_config_dir(), "yabause", "gtk", "yabause.ini", NULL);

	if (! g_file_test(inifile, G_FILE_TEST_EXISTS)) {
		// no inifile found, but it could be in the old location
		gchar * oldinifile = g_build_filename(g_get_user_config_dir(), "yabause.ini", NULL);

		// we need to create the directory for the new file anyways
		gchar * xdgpath = g_build_filename(g_get_user_config_dir(), "yabause", "gtk", NULL);

		if (! g_file_test(xdgpath, G_FILE_TEST_EXISTS))
			g_mkdir_with_parents(xdgpath, 0755);
		g_free(xdgpath);

		if (g_file_test(oldinifile, G_FILE_TEST_EXISTS)) {
			// ok, we found an old .ini file, let's copy the content
			gchar * data;

			g_file_get_contents(oldinifile, &data, NULL, NULL);
			g_file_set_contents(inifile, data, -1, NULL);
		}

		g_free(oldinifile);
	}
	
	keyfile = g_key_file_new();

	gtk_init(&argc, &argv);
#ifdef HAVE_LIBGTKGLEXT
	gtk_gl_init(&argc, &argv);
#endif

	yui_settings_init();

#ifdef HAVE_LIBMINI18N
	mini18n_set_domain(YTSDIR);
	g_key_file_load_from_file(keyfile, inifile, G_KEY_FILE_NONE, 0);
	mini18n_set_locale(g_key_file_get_value(keyfile, "General", "TranslationPath", NULL));
#endif

	yui = yui_new();

	yui_settings_load();

	gtk_window_move(GTK_WINDOW(yui), g_key_file_get_integer(keyfile, "Gtk", "X", 0), g_key_file_get_integer(keyfile, "Gtk", "Y", 0));

#ifndef NO_CLI
   //handle command line arguments
   for (i = 1; i < argc; ++i) {
      if (argv[i]) {
         //show usage
         if (0 == strcmp(argv[i], "-h") || 0 == strcmp(argv[i], "-?") || 0 == strcmp(argv[i], "--help")) {
            print_usage(argv[0]);
            return 0;
         }
			
         //set bios
         if (0 == strcmp(argv[i], "-b") && argv[i + 1]) {
            g_strlcpy(biospath, argv[i + 1], 256);
            yinit.biospath = biospath;
	 } else if (strstr(argv[i], "--bios=")) {
            g_strlcpy(biospath, argv[i] + strlen("--bios="), 256);
            yinit.biospath = biospath;
	 }
         //set iso
         else if (0 == strcmp(argv[i], "-i") && argv[i + 1]) {
            g_strlcpy(cdpath, argv[i + 1], 256);
	    yinit.cdcoretype = 1;
	 } else if (strstr(argv[i], "--iso=")) {
            g_strlcpy(cdpath, argv[i] + strlen("--iso="), 256);
	    yinit.cdcoretype = 1;
	 }
         //set cdrom
	 else if (0 == strcmp(argv[i], "-c") && argv[i + 1]) {
            g_strlcpy(cdpath, argv[i + 1], 256);
	    yinit.cdcoretype = 2;
	 } else if (strstr(argv[i], "--cdrom=")) {
            g_strlcpy(cdpath, argv[i] + strlen("--cdrom="), 256);
	    yinit.cdcoretype = 2;
	 }
         // Set sound
         else if (strcmp(argv[i], "-ns") == 0 || strcmp(argv[i], "--nosound") == 0) {
	    yinit.sndcoretype = 0;
	 }
	 // Autoload
	 else if (strcmp(argv[i], "--autoload") == 0) {
            yui_window_start(YUI_WINDOW(yui));
            YuiLoadState();
            yui_window_run(YUI_WINDOW(yui));
	 }
	 // Autostart
	 else if (strcmp(argv[i], "-a") == 0 || strcmp(argv[i], "--autostart") == 0) {
            yui_window_run(YUI_WINDOW(yui));
	 }
	 // Fullscreen
	 else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--fullscreen") == 0) {
            yui_window_set_fullscreen(YUI_WINDOW(yui), TRUE);
	 }
         // Auto frame skip
         else if (strstr(argv[i], "--autoframeskip=")) {
            int fscount;
            int fsenable;
            fscount = sscanf(argv[i] + strlen("--autoframeskip="), "%d", &fsenable);
            if (fscount > 0)
               yui_window_set_frameskip(YUI_WINDOW(yui), fsenable);
         }
	 // Binary
	 else if (strstr(argv[i], "--binary=")) {
	    char binname[1024];
	    unsigned int binaddress;
	    int bincount;

	    bincount = sscanf(argv[i] + strlen("--binary="), "%[^:]:%x", binname, &binaddress);
	    if (bincount > 0) {
	       if (bincount < 2) binaddress = 0x06004000;

               yui_window_run(YUI_WINDOW(yui));
	       MappedMemoryLoadExec(binname, binaddress);
	    }
	 }
      }
   }
#endif

	gtk_main ();

	YabauseDeInit();
	LogStop();

	return 0;
}

void YuiSwapBuffers(void) {
	yui_window_update(YUI_WINDOW(yui));
}

void yui_conf(void) {
	gint result;
	GtkWidget * dialog;

	dialog = create_dialog1();

	result = gtk_dialog_run(GTK_DIALOG(dialog));
	gtk_widget_destroy(dialog);
	switch(result) {
		case GTK_RESPONSE_OK:
                {
			gboolean mustRestart;
			g_file_set_contents(inifile, g_key_file_to_data(keyfile, 0, 0), -1, 0);
			mustRestart = yui_settings_load();
			if (mustRestart) {
                       		GtkWidget* warningDlg = gtk_message_dialog_new (GTK_WINDOW(yui),
                                	                                        GTK_DIALOG_MODAL,
                                        	                                GTK_MESSAGE_WARNING,
                                                	                        GTK_BUTTONS_OK,
                                                        	                "You must restart Yabause before the changes take effect.");

                        	gtk_dialog_run (GTK_DIALOG(warningDlg));
                        	gtk_widget_destroy (warningDlg); 
			}
			break;
                }
		case GTK_RESPONSE_CANCEL:
			g_key_file_load_from_file(keyfile, inifile, G_KEY_FILE_NONE, 0);
			break;
	}
}

void yui_resize(guint width, guint height, gboolean fullscreen) {
	if (width <= 0) width = 320;
	if (height <= 0) height = 224;

	if (g_key_file_get_integer(keyfile, "General", "KeepRatio", 0))
	{
		GdkGeometry geometry;
		geometry.min_aspect = (float) width / height;
		geometry.max_aspect = (float) width / height;
		gtk_window_set_geometry_hints(GTK_WINDOW(yui), YUI_WINDOW(yui)->area, &geometry, GDK_HINT_ASPECT);
	}
	else
	{
		gtk_window_set_geometry_hints(GTK_WINDOW(yui), YUI_WINDOW(yui)->area, NULL, 0);
	}

	gtk_window_resize(GTK_WINDOW(yui), width, height + YUI_WINDOW(yui)->menu->allocation.height);

	yui_window_set_fullscreen(YUI_WINDOW(yui), fullscreen);
}
