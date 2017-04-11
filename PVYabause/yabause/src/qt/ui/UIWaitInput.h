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
#ifndef UIWAITINPUT_H
#define UIWAITINPUT_H

#include "ui_UIWaitInput.h"
#include "../QtYabause.h"

class UIWaitInput : public QDialog, public Ui::UIWaitInput
{
	Q_OBJECT
public:
	UIWaitInput( PerInterface_struct* core, const QString& padKey, QWidget* parent = 0 );

	inline QString keyString() const { return mKeyString; }

protected:
	PerInterface_struct* mCore;
	QString mPadKey;
	QString mKeyString;
	bool mScanningInput;

	void keyPressEvent( QKeyEvent* event );

protected slots:
	void inputScan_timeout();
};

#endif // UIWAITINPUT_H
