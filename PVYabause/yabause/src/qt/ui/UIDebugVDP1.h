/*	Copyright 2012 Theo Berkau <cwx@cyberwarriorx.com>

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
#ifndef UIDEBUGVDP1_H
#define UIDEBUGVDP1_H

#include "ui_UIDebugVDP1.h"
#include "../QtYabause.h"

class UIDebugVDP1 : public QDialog, public Ui::UIDebugVDP1
{
	Q_OBJECT
public:
	UIDebugVDP1( QWidget* parent = 0 );
	~UIDebugVDP1();

protected:
   u32 *vdp1texture;
   int vdp1texturew, vdp1textureh;

protected slots:
   void on_lwCommandList_itemSelectionChanged ();
   void on_pbSaveBitmap_clicked ();

};

#endif // UIDEBUGVDP1_H
