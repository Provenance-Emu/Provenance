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
#ifndef UICHEATS_H
#define UICHEATS_H

#include "ui_UICheats.h"
#include "../QtYabause.h"

class UICheats : public QDialog, public Ui::UICheats
{
	Q_OBJECT

public:
	UICheats( QWidget* parent = 0 );

protected:
	cheatlist_struct* mCheats;

	void addCode( int id );
	void addARCode( const QString& code, const QString& description );
	void addRawCode( int type, const QString& address, const QString& value, const QString& description );

protected slots:
	void on_twCheats_itemSelectionChanged();
	void on_twCheats_itemDoubleClicked( QTreeWidgetItem* item, int column );
	void on_pbDelete_clicked();
	void on_pbClear_clicked();
	void on_pbAR_clicked();
	void on_pbRaw_clicked();
	void on_pbSaveFile_clicked();
	void on_pbLoadFile_clicked();
};

#endif // UICHEATS_H
