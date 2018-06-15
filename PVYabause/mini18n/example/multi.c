/*  Copyright 2010 Guillaume Duhamel
  
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

#include "../src/mini18n-multi.h"
#include <stdio.h>

int main(int argc, char ** argv) {
	mini18n_t lang = (mini18n_t) 0;
	mini18n_t base = (mini18n_t) 0;

	lang = mini18n_create();
	base = mini18n_create();
	if (argc > 1) mini18n_load(lang, argv[1]);

	mini18n_set_log_filename(lang, "out");

	printf("%s\n", mini18n_get(base, "Hello!"));
	printf("%s\n", mini18n_get(lang, "Hello!"));

	mini18n_destroy(lang);
	mini18n_destroy(base);
}
