/*--------------------------------------------------
   TGB Dual - Gameboy Emulator -
   Copyright (C) 2001  Hii

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

//---------------------------------------------
// エミュレーション結果の表現法/インターフェース
// Emulation interface representation method of result

#ifndef RENDERER_H
#define RENDERER_H

#include "gb_types.h"

class sound_renderer
{
public:
	virtual void render(short *buf,int samples)=0;
};

class renderer
{
public:
	void set_sound_renderer(sound_renderer *ref) { snd_render=ref; };

	virtual void reset()=0;
	virtual void refresh()=0;
	virtual void render_screen(byte *buf,int width,int height,int depth)=0;
	virtual int check_pad()=0;
	virtual word map_color(word gb_col)=0;
	virtual word unmap_color(word gb_col)=0;

	virtual byte get_time(int type)=0;
	virtual void set_time(int type,byte dat)=0;

	virtual word get_sensor(bool x_y)=0;

	virtual void set_bibrate(bool bibrate)=0;

protected:
	sound_renderer *snd_render;
};

#endif
