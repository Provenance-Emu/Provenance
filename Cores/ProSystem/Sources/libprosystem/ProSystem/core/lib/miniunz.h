/*
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
#ifndef MINIUNZ_H
#define MINIUNZ_H

//! Look for possible filename in zip archive
char *find_possible_filename_in_zip (char *zipfilename, const char* extstr);

//! Extract file content from zip archive
int extract_file_in_memory (char *zipfilename, char *archivedfile,
			    size_t * unzipped_size);

#endif
