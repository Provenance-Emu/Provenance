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
#ifndef UIBACKUPRAM_H
#define UIBACKUPRAM_H

#include "ui_UIBackupRam.h"

class UIBackupRam : public QDialog, public Ui::UIBackupRam
{
	Q_OBJECT

public:
	UIBackupRam( QWidget* parent = 0 );

protected:
	void refreshSaveList();

protected slots:
	void on_cbDeviceList_currentIndexChanged( int id );
	void on_lwSaveList_itemSelectionChanged();
	void on_pbDelete_clicked();
	void on_pbFormat_clicked();
};

#endif // UIBACKUPRAM_H
