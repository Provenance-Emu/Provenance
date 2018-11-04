/*	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>

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
#ifndef UICHEATRAW_H
#define UICHEATRAW_H

#include "ui_UICheatRaw.h"

class QButtonGroup;

class UICheatRaw : public QDialog, public Ui::UICheatRaw
{
	Q_OBJECT

public:
	UICheatRaw( QWidget* parent = 0 );

	inline int type() const { return mButtonGroup->checkedId(); }

protected:
	QButtonGroup* mButtonGroup;
};

#endif // UICHEATRAW_H
