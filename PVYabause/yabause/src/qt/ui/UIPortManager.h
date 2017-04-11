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
#ifndef UIPORTMANAGER_H
#define UIPORTMANAGER_H

#include "ui_UIPortManager.h"
#include "../QtYabause.h"

class UIPortManager : public QGroupBox, public Ui::UIPortManager
{
	Q_OBJECT

public:
	static const QString mSettingsKey;
	static const QString mSettingsType;

	UIPortManager( QWidget* parent = 0 );
	virtual ~UIPortManager();

	void setPort( uint portId );
	void setCore( PerInterface_struct* core );
	void loadSettings();

protected:
	uint mPort;
	PerInterface_struct* mCore;

protected slots:
	void cbTypeController_currentIndexChanged( int id );
	void tbSetJoystick_clicked();
	void tbClearJoystick_clicked();
};

#endif // UIPORTMANAGER_H
