/*  Copyright 2009 Guillaume Duhamel
  
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
#include "mini18n_pv_file_po.h"

int file_po_load(mini18n_hash_t * hash, FILE * f) {
	char buffer[1024];
	char key[1024];
	char value[1024];
	char * c;
	int state = 0;
	int i;

	while(fgets(buffer, 1024, f)) {
		c = buffer;
		while(*c != '\0') {
			switch(state) {
				case 0:
					if (*c == '#') {
						state = 7;
						break;
					}

					if (!strncmp(c, "msgid", 5)) {
						i = 0;
						state = 1;
						break;
					}

					/* unexpected char at state 0, should not be a po file, bye */
					return -1;
				case 1:
					while(*c != '"') c++;
					state = 2;
					break;
				case 2:
					while(*c != '"') key[i++] = *c++;
					key[i] = '\0';
					state = 3;
					break;
				case 3:
					if (*c == '"') {
						state = 2;
						break;
					}

					if (!strncmp(c, "msgstr", 6)) {
						i = 0;
						state = 4;
					}
					break;
				case 4:
					while(*c != '"') c++;
					state = 5;
					break;
				case 5:
					while(*c != '"') value[i++] = *c++;
					value[i] = '\0';
					state = 6;
					break;
				case 6:
					if (*c == '"') {
						state = 5;
						break;
					}

					if (!strncmp(c, "msgid", 5)) {
						mini18n_hash_add(hash, key, value);
						i = 0;
						state = 1;
					}
					break;
				case 7: /* comment */
					while (*c != '\n') c++;
					state = 0;
					break;
			}
			c++;
		}
	}

	return 0;
}

mini18n_file_t mini18n_file_po = {
	file_po_load
};
