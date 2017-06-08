/*
  PokeMini Music Converter
  Copyright (C) 2011-2015  JustBurn

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

#ifndef MUS_CONV_H
#define MUS_CONV_H

#include <stdint.h>

enum {
	FORMAT_RAW,
	FORMAT_ASM,
	FORMAT_C
};

void init_confs();
int load_confs_args(int argc, char **argv);

const char *readmus_num(const char *s, int *nout, int maxhdigits);
char *readmus_line(FILE *fi, char *s, int len);
int convertmml_file(const char *mmlfile);

void *open_output(int format, const char *filename);
void comment_output(void *foptr, int format, const char *fmt, ...);
int write_output(void *foptr, int format, const char *varname, unsigned char *data, int bytes);
int wropen_output(void *foptr, int format, int bits, const char *varname);
int wrdata_output(void *foptr, int format, int bits, int data);
int wrclose_output(void *foptr, int format);
void close_output(void *foptr, int format);

#endif
