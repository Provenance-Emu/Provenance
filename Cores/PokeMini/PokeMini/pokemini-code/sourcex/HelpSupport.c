/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <gtk/gtk.h>
#endif

#include "PokeMini.h"

void HelpLaunchURL(const char *url)
{
#ifdef _WIN32
	ShellExecuteA(NULL, "open", url, "", NULL, SW_SHOWNORMAL);
#else
	gtk_show_uri(NULL, url, GDK_CURRENT_TIME, NULL);
#endif
}

void HelpLaunchDoc(const char *sid)
{
	char tmp[PMTMPV];
#ifdef _WIN32
	sprintf(tmp, "%s\\doc\\%s.html", PokeMini_ExecDir, sid);
	ShellExecuteA(NULL, "open", tmp, "", NULL, SW_SHOWNORMAL);
#else
	sprintf(tmp, "file://%s/doc/%s.html", PokeMini_ExecDir, sid);
	gtk_show_uri(NULL, tmp, GDK_CURRENT_TIME, NULL);
#endif
}
