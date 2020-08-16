/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */


#include "common.h"
#include "../../wave.h"
#include "main.h" //For GetRomName()
#include "utils/xstring.h"

int CloseWave()
{

 return(FCEUI_EndWaveRecord());
}

/// Shows a Open File dialog and starts logging sound.
/// @return Flag that indicates failure (0) or success (1).
bool CreateSoundSave()
{
	const char filter[]="MS WAVE (*.wav)\0*.wav\0All Files (*.*)\0*.*\0\0";
	char nameo[2048];
	OPENFILENAME ofn;

	FCEUI_EndWaveRecord();

	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Log Sound As...";
	ofn.lpstrFilter=filter;
	strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	ofn.lpstrFile=nameo;
	ofn.lpstrDefExt="wav";
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;

	if(GetSaveFileName(&ofn))
		return FCEUI_BeginWaveRecord(nameo);

	return false;
}
