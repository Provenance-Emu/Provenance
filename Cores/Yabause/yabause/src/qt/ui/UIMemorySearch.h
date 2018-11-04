/*	Copyright 2013 Theo Berkau <cwx@cyberwarriorx.com>

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
#ifndef UIMEMORYSEARCH_H
#define UIMEMORYSEARCH_H

#include "ui_UIMemorySearch.h"
#include "../YabauseThread.h"
#include "../QtYabause.h"

class UIMemorySearch : public QDialog, public Ui::UIMemorySearch
{
	Q_OBJECT

public:
	UIMemorySearch( QWidget* parent = 0 );
   void setParameters(int type, QString string, u32 startAddress, u32 endAddress);
private:
   void adjustSearchValueQValidator();
protected:

protected slots:
   void accept();
   void on_cbType_currentIndexChanged(int index);
	void on_leValue_textChanged( const QString & text );
};

#endif // UIMEMORYSEARCH_H
