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
#ifndef UIMEMORYTRANSFER_H
#define UIMEMORYTRANSFER_H

#include "ui_UIMemoryTransfer.h"
#include "../YabauseThread.h"
#include "../QtYabause.h"

class UIMemoryTransfer : public QDialog, public Ui::UIMemoryTransfer
{
	Q_OBJECT
public:
	UIMemoryTransfer( YabauseThread *mYabauseThread, QWidget* parent = 0 );

protected:
   YabauseThread *mYabauseThread;
   bool areSettingsValid();

protected slots:
    void on_leFile_textChanged( const QString & text );
    void on_leStartAddress_textChanged( const QString & text );
    void on_leEndAddress_textChanged( const QString & text );
    void on_rbUpload_toggled(bool checked);
    void on_tbBrowse_clicked();
	 void accept();
};

#endif // UIMEMORYTRANSFER_H
