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
#include "mini18n_pv_file_yts.h"

int file_yts_load(mini18n_hash_t * hash, FILE * f) {
	char buffer[1024];
	char key[1024];
	char value[1024];

	while (fgets(buffer, 1024, f)) {
		int i = 0, j = 0, done = 0, state = 0, empty = 1;
		char c;

		while(!done && (i < 1024)) {
			c = buffer[i];
			switch(state) {
				case 0:
					switch(c) {
						case '\\':
							/* escape character, we're now in state 1 */
							state = 1;
							break;
						case '|':
							/* separator, we're done */
							key[j] = '\0';
							j = 0;
							state = 2;
							break;
						default:
							/* we're still reading the key */
							key[j] = c;
							j++;
							break;
					}
					break;
				case 1:
					switch(c) {
						case 'n':
							key[j] = '\n';
							break;
						case 't':
							key[j] = '\t';
							break;
						default:
							key[j] = c;
					}
					j++;
					state = 0;
					break;
				case 2:
					switch(c) {
						case '\n':
							value[j] = '\0';
							done = 1;
							break;
						case '\\':
							/* escape character, move to state 3 */
							state = 3;
							break;
						default:
							empty = 0;
							value[j] = c;
							j++;
							break;
					}
					break;
				case 3:
					switch(c) {
						case 'n':
							value[j] = '\n';
							break;
						case 't':
							value[j] = '\t';
							break;
						default:
							value[j] = c;
					}
					j++;
					state = 2;
					empty = 0;
					break;
			}
			i++;
		}

		if (done && !empty) {
			mini18n_hash_add(hash, key, value);
		}
	}

	return 0;
}

mini18n_file_t mini18n_file_yts = {
	file_yts_load
};
