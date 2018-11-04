/*  Copyright 2004 Stephane Dallongeville
    Copyright 2004-2007 Theo Berkau
    Copyright 2006 Guillaume Duhamel

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

/*! \file snddummy.c
    \brief Dummy sound interface.
*/

#include "scsp.h"

//////////////////////////////////////////////////////////////////////////////
// Dummy Sound Interface
//////////////////////////////////////////////////////////////////////////////

static int SNDDummyInit(void);
static void SNDDummyDeInit(void);
static int SNDDummyReset(void);
static int SNDDummyChangeVideoFormat(int vertfreq);
static void SNDDummyUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples);
static u32 SNDDummyGetAudioSpace(void);
static void SNDDummyMuteAudio(void);
static void SNDDummyUnMuteAudio(void);
static void SNDDummySetVolume(int volume);

SoundInterface_struct SNDDummy = {
SNDCORE_DUMMY,
"Dummy Sound Interface",
SNDDummyInit,
SNDDummyDeInit,
SNDDummyReset,
SNDDummyChangeVideoFormat,
SNDDummyUpdateAudio,
SNDDummyGetAudioSpace,
SNDDummyMuteAudio,
SNDDummyUnMuteAudio,
SNDDummySetVolume
};

//////////////////////////////////////////////////////////////////////////////

static int SNDDummyInit(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDDummyDeInit(void)
{
}

//////////////////////////////////////////////////////////////////////////////

static int SNDDummyReset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int SNDDummyChangeVideoFormat(UNUSED int vertfreq)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDDummyUpdateAudio(UNUSED u32 *leftchanbuffer, UNUSED u32 *rightchanbuffer, UNUSED u32 num_samples)
{
}

//////////////////////////////////////////////////////////////////////////////

static u32 SNDDummyGetAudioSpace(void)
{
   /* A "hack" to get dummy sound core working enough
    * so videos are not "freezing". Values have been
    * found by experiments... I don't have a clue why
    * they are working ^^;
    */
   static int i = 0;
   i++;
   if (i == 55) {
      i = 0;
      return 85;
   } else {
      return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void SNDDummyMuteAudio()
{
}

//////////////////////////////////////////////////////////////////////////////

void SNDDummyUnMuteAudio()
{
}

//////////////////////////////////////////////////////////////////////////////

void SNDDummySetVolume(UNUSED int volume)
{
}

//////////////////////////////////////////////////////////////////////////////
