/*	Copyright 2012-2013 Theo Berkau <cwx@cyberwarriorx.com>

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
#ifndef UIMEMORYEDITOR_H
#define UIMEMORYEDITOR_H

#include "ui_UIMemoryEditor.h"
#include <QProgressDialog>
#include "../YabauseThread.h"
#include "../QtYabause.h"

class MemorySearch : public QObject
{
   Q_OBJECT

public:
   MemorySearch( class UIMemorySearch *memorySearch, QObject* owner = 0 );
   ~MemorySearch();
   void setStartAddress( u32 address );
   void start();

public slots:
   void process();
   void cancel();

signals:
   void setBarValue(int progress);
   void setBarRange(int minimum, int maximum);
   void searchResult(bool found, bool cancel, u32 address);

private:
   int steps;
   QTimer *timer;
   u32 searchSize;
   int searchType;
   QString searchString;
   u32 curAddress, startAddress, endAddress;
};

class UIMemoryEditor : public QDialog, public Ui::UIMemoryEditor
{
	Q_OBJECT
public:
   UIMemoryEditor( YabauseThread *mYabauseThread, QWidget* p );
private:
   u32 gotoAddress;
   int searchType;
   QString searchString;
   u32 searchStartAddress;
   u32 searchEndAddress;

signals:
   void killProgressDialog();

protected:

protected slots:
   void on_pbGotoAddress_clicked();
   void on_pbSaveSelected_clicked();
   void on_pbSaveTab_clicked();
   void on_pbSearchMemory_clicked();
   void searchResult(bool found, bool cancel, u32 address);
};

#endif // UIMEMORYEDITOR_H
