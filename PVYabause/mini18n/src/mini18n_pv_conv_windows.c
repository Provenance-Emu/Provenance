/*  Copyright 2008 Guillaume Duhamel
  
    This file is part of mini18n.
  
    mini18n is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
  
    mini18n is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
  
    You should have received a copy of the GNU General Public License
    along with mini18n; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "mini18n.h"
#include "mini18n_pv_conv_windows.h"
#include <windows.h>

void * conv_windows_utf16(const char * source) {
	WCHAR * utf16;
	int needed = MultiByteToWideChar(CP_UTF8, 0, source, -1, NULL, 0);
	utf16 = malloc(sizeof(WCHAR) * needed);
	MultiByteToWideChar(CP_UTF8, 0, source, -1, utf16, needed);
	return utf16;
}

mini18n_conv_t mini18n_conv_windows_utf16 = {
	MINI18N_UTF16,
	&mini18n_wcs,
	conv_windows_utf16
};
