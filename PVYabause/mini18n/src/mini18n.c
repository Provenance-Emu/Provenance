/*  Copyright 2008-2010 Guillaume Duhamel
  
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
#include "mini18n-multi.h"

static mini18n_t currentlang = (mini18n_t) 0;

int mini18n_set_domain(const char * folder) {
	if (currentlang == (mini18n_t) 0)
		currentlang = mini18n_create();
	return mini18n_load_system(currentlang, folder);
}

int mini18n_set_locale(const char * locale) {
	if (currentlang == (mini18n_t) 0)
		currentlang = mini18n_create();
	return mini18n_load(currentlang, locale);
}

int mini18n_set_log(const char * filename) {
	return mini18n_set_log_filename(currentlang, filename);
}

const char * mini18n(const char * source) {
	return mini18n_get(currentlang, source);
}

const void * mini18n_with_conversion(const char * source, unsigned int format) {
	return mini18n_get_with_conversion(currentlang, source, format);
}

void mini18n_close(void) {
	mini18n_destroy(currentlang);
	currentlang = (mini18n_t) 0;
}
