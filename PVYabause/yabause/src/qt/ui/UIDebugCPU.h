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
#ifndef UIDEBUGCPU_H
#define UIDEBUGCPU_H

#include "ui_UIDebugCPU.h"
#include "../YabauseThread.h"
#include "../QtYabause.h"

class UIDebugCPU : public QDialog, public Ui::UIDebugCPU
{
	Q_OBJECT

public:
	UIDebugCPU( YabauseThread *mYabauseThread, QWidget* parent = 0 );
   virtual void updateRegList();
   virtual void updateCodeList(u32 addr);
   virtual u32 getRegister(int index, int *size);
   virtual void setRegister(int index, u32 value);
   virtual bool addCodeBreakpoint(u32 addr);
   virtual bool delCodeBreakpoint(u32 addr);
   virtual bool addMemoryBreakpoint(u32 addr, u32 flags);
   virtual bool delMemoryBreakpoint(u32 addr);
   virtual void stepInto();
   virtual void stepOver();
   virtual void stepOut();
   virtual void reserved1();
   virtual void reserved2();
   virtual void reserved3();
   virtual void reserved4();
   virtual void reserved5();

protected:
   YabauseThread *mYabauseThread;
   bool isReadWriteButtonAndTextOK();

protected slots:
   void on_lwRegisters_itemDoubleClicked ( QListWidgetItem * item );
   void on_lwBackTrace_itemDoubleClicked ( QListWidgetItem * item );
   void on_twTrackInfLoop_itemDoubleClicked ( QTableWidgetItem * item );
   void on_leCodeBreakpoint_textChanged( const QString & text);
   void on_leMemoryBreakpoint_textChanged( const QString & text);
   void on_lwCodeBreakpoints_itemSelectionChanged ();
   void on_pbAddCodeBreakpoint_clicked();
   void on_pbDelCodeBreakpoint_clicked();
   void on_lwMemoryBreakpoints_itemSelectionChanged ();
   void on_pbAddMemoryBreakpoint_clicked();
   void on_pbDelMemoryBreakpoint_clicked();
   void on_cbRead_toggled(bool enable);
   void on_cbWrite_toggled(bool enable);
   void on_cbReadByte_toggled(bool enable);
   void on_cbReadWord_toggled(bool enable);
   void on_cbReadLong_toggled(bool enable);
   void on_cbWriteByte_toggled(bool enable);
   void on_cbWriteWord_toggled(bool enable);
   void on_cbWriteLong_toggled(bool enable);
   void on_pbStepInto_clicked();
   void on_pbStepOver_clicked();
   void on_pbStepOut_clicked();
   void on_pbMemoryTransfer_clicked();
   void on_pbMemoryEditor_clicked();

   void on_pbReserved1_clicked();
   void on_pbReserved2_clicked();
   void on_pbReserved3_clicked();
   void on_pbReserved4_clicked();
   void on_pbReserved5_clicked();

   void toggleCodeBreakpoint(u32 addr);
};

#endif // UIDEBUGCPU_H
