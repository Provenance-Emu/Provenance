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

#include "../gb_core/renderer.h"

class dmy_renderer : public renderer
{
public:
	dmy_renderer(int which);
	virtual ~dmy_renderer(){};

	virtual void reset() {}
	virtual word get_sensor(bool x_y) { return 0; }
	virtual void set_bibrate(bool bibrate) {}

	virtual void render_screen(byte *buf,int width,int height,int depth);
	virtual word map_color(word gb_col);
	virtual word unmap_color(word gb_col);
	virtual int check_pad();
	virtual void refresh();
	virtual byte get_time(int type);
	virtual void set_time(int type,byte dat);

	dword fixed_time;
private:
	int cur_time;
	int which_gb;
	bool rgb565;
};
