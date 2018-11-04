/*
  PokeMini Music Converter
  Copyright (C) 2011-2012  JustBurn

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

#ifndef SAUDIO_AL_H
#define SAUDIO_AL_H

#include <stdint.h>

#define NUMSNDBUFFERS	4

typedef void (*saudio_fillcb)(int16_t *stream, int len);

int init_saudio(saudio_fillcb cb, int bufsize);
void term_saudio(void);

int play_saudio(void);
int stop_saudio(void);

int sync_saudio(void);

void sleep_saudio(int ms);

#endif
