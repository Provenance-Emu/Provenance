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
#ifndef UIDEBUGVDP2VIEWER_H
#define UIDEBUGVDP2VIEWER_H

#include "ui_UIDebugVDP2Viewer.h"
#include "../QtYabause.h"

class UIDebugVDP2Viewer : public QDialog, public Ui::UIDebugVDP2Viewer
{
	Q_OBJECT
public:
	UIDebugVDP2Viewer( QWidget* parent = 0 );

protected:
   pixel_t *vdp2texture;
   int width, height;
protected slots:
   void on_cbScreen_currentIndexChanged ( int index );
   void on_pbSaveAsBitmap_clicked ();
};

#endif // UIDEBUGVDP2VIEWER_H
