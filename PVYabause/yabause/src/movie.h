/*  
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

#ifndef MOVIE_H
#define MOVIE_H

#include "core.h"

#define Stopped	  1
#define Recording 2
#define Playback  3

#define RunNormal   0
#define Paused      1
#define NeedAdvance 2

void DoMovie(void);

struct MovieStruct
{
	int Status;
	FILE *fp;
	int ReadOnly;
	int Rerecords;
	int Size;
	int Frames;
	const char* filename;
};

extern struct MovieStruct Movie;

struct MovieBufferStruct
{
	int size;
	char* data;
};

struct MovieBufferStruct ReadMovieIntoABuffer(FILE* fp);

void MovieLoadState(const char * filename);

void SaveMovieInState(FILE* fp, IOCheck_struct check);
void ReadMovieInState(FILE* fp); 

void TestWrite(struct MovieBufferStruct tempbuffer);

void MovieToggleReadOnly(void);

void TruncateMovie(struct MovieStruct Movie);

void DoFrameAdvance(void);

int SaveMovie(const char *filename);
int PlayMovie(const char *filename);
void StopMovie(void);

const char *MakeMovieStateName(const char *filename);

void MovieReadState(FILE* fp, const char * filename);

void PauseOrUnpause(void);

int IsMovieLoaded(void);

extern int framecounter;
extern int LagFrameFlag;
extern int lagframecounter;
extern char MovieStatus[40];
extern char InputDisplayString[40];
extern int FrameAdvanceVariable;
#endif
