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

#include "UIDebugCPU.h"
#include "UIHexInput.h"
#include "UIMemoryEditor.h"
#include "UIMemoryTransfer.h"
#include "../CommonDialogs.h"

UIDebugCPU::UIDebugCPU( YabauseThread *mYabauseThread, QWidget* p )
	: QDialog( p )
{
	// set up dialog
	setupUi( this );
	if ( p && !p->isFullScreen() )
		setWindowFlags( Qt::Sheet );

	// Disable unimplemented functions
	gbBackTrace->setVisible( false );
	pbStepOver->setVisible( false );
	pbStepOut->setVisible( false );
	pbReserved1->setVisible( false );
	pbReserved2->setVisible( false );
	pbReserved3->setVisible( false );
	pbReserved4->setVisible( false );
	pbReserved5->setVisible( false );

	pbAddCodeBreakpoint->setEnabled( false );
	pbDelCodeBreakpoint->setEnabled( false );
	pbAddMemoryBreakpoint->setEnabled( false );
	pbDelMemoryBreakpoint->setEnabled( false );

	// Clear code/memory breakpoint text fields
	leCodeBreakpoint->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leCodeBreakpoint));
	leMemoryBreakpoint->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leMemoryBreakpoint));
	leCodeBreakpoint->setText("");
	leMemoryBreakpoint->setText("");

	connect( lwDisassembledCode, SIGNAL( toggleCodeBreakpoint(u32) ), this, SLOT( toggleCodeBreakpoint(u32) ) );

	this->mYabauseThread = mYabauseThread;

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIDebugCPU::on_lwRegisters_itemDoubleClicked ( QListWidgetItem * item )
{
	int size;

	u32 value = getRegister(lwRegisters->row(item), &size);

	UIHexInput hex(value, size, this);
	if (hex.exec() == QDialog::Accepted)
	{
		value = hex.getValue();
		setRegister(lwRegisters->row(item), value);
	}

	updateRegList();
}

void UIDebugCPU::on_lwBackTrace_itemDoubleClicked ( QListWidgetItem * item )
{
	updateCodeList(item->text().toUInt(NULL, 16));
}

void UIDebugCPU::on_twTrackInfLoop_itemDoubleClicked ( QTableWidgetItem * item )
{
	if (item->column() == 0)
		updateCodeList(item->text().toUInt(NULL, 16));
}

void UIDebugCPU::on_leCodeBreakpoint_textChanged( const QString & text )
{
   pbAddCodeBreakpoint->setEnabled(text.length() > 0);
}

bool UIDebugCPU::isReadWriteButtonAndTextOK()
{
	if (leMemoryBreakpoint->text().length() > 0)
	{
		if (cbRead->isChecked() &&
		(cbReadByte->isChecked() || cbReadWord->isChecked() || cbReadLong->isChecked()))
			return true;
		else if (cbWrite->isChecked() &&
			(cbWriteByte->isChecked() || cbWriteWord->isChecked() || cbWriteLong->isChecked()))
			return true;
	}
	return false;
}

void UIDebugCPU::on_leMemoryBreakpoint_textChanged( const QString & text )
{
	// Only enable Memory breakpoint add button if address is valid and read/write and size is checked
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_lwCodeBreakpoints_itemSelectionChanged ()
{
	pbDelCodeBreakpoint->setEnabled(true);
}

void UIDebugCPU::on_pbAddCodeBreakpoint_clicked()
{
	// Only add breakpoint to list if all goes well with emulator
	if (addCodeBreakpoint(leCodeBreakpoint->text().toInt(0, 16)))
		lwCodeBreakpoints->addItem(leCodeBreakpoint->text());
}

void UIDebugCPU::on_pbDelCodeBreakpoint_clicked()
{
	QList<QListWidgetItem *> list=lwCodeBreakpoints->selectedItems ();
	for (int i = 0; i < list.count(); i++)
	{
		QListWidgetItem *item=list.value(i);
		u32 addr = item->text().toUInt(0, 16);
		delCodeBreakpoint(addr);
	}
	qDeleteAll(lwCodeBreakpoints->selectedItems ());
	pbDelCodeBreakpoint->setEnabled(lwCodeBreakpoints->count() > 0);
}

void UIDebugCPU::on_lwMemoryBreakpoints_itemSelectionChanged ()
{
	pbDelMemoryBreakpoint->setEnabled(true);
}

void UIDebugCPU::on_pbAddMemoryBreakpoint_clicked()
{
	u32 flags=0;

	// Get RW flags
	if (cbRead->checkState() == Qt::Checked)
	{
		if (cbReadByte->checkState() == Qt::Checked)
			flags |= BREAK_BYTEREAD;
		if (cbReadWord->checkState() == Qt::Checked)
			flags |= BREAK_WORDREAD;
		if (cbReadLong->checkState() == Qt::Checked)
			flags |= BREAK_LONGREAD;
	}

	if (cbWrite->checkState() == Qt::Checked)
	{
		if (cbWriteByte->checkState() == Qt::Checked)
			flags |= BREAK_BYTEWRITE;
		if (cbWriteWord->checkState() == Qt::Checked)
			flags |= BREAK_WORDWRITE;
		if (cbWriteLong->checkState() == Qt::Checked)
			flags |= BREAK_LONGWRITE;
	}

	// Only add breakpoint to list if all goes well with emulator
	if (addMemoryBreakpoint(leMemoryBreakpoint->text().toInt(0, 16), flags))
		lwMemoryBreakpoints->addItem(leMemoryBreakpoint->text());
}

void UIDebugCPU::on_pbDelMemoryBreakpoint_clicked()
{
	QList<QListWidgetItem *> list=lwMemoryBreakpoints->selectedItems ();
	for (int i = 0; i < list.count(); i++)
	{
		QListWidgetItem *item=list.value(i);
		u32 addr = item->text().toUInt(0, 16);
		delMemoryBreakpoint(addr);
	}
	qDeleteAll(lwMemoryBreakpoints->selectedItems ());
	pbDelMemoryBreakpoint->setEnabled(lwMemoryBreakpoints->count() > 0);
}

void UIDebugCPU::on_cbRead_toggled(bool enable)
{
	// Enable Byte/Word/Long if Read is checked
	cbReadByte->setEnabled(enable);
	cbReadWord->setEnabled(enable);
	cbReadLong->setEnabled(enable);

	// Enable Add button if address is valid and read/write and size is checked
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbWrite_toggled(bool enable)
{
	// Enable Byte/Word/Long if Write is checked
	cbWriteByte->setEnabled(enable);
	cbWriteWord->setEnabled(enable);
	cbWriteLong->setEnabled(enable);

	// Enable Add button if address is valid and read/write and size is checked
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbReadByte_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbReadWord_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbReadLong_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbWriteByte_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbWriteWord_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_cbWriteLong_toggled(bool enable)
{
	pbAddMemoryBreakpoint->setEnabled(isReadWriteButtonAndTextOK());
}

void UIDebugCPU::on_pbStepInto_clicked()
{
	stepInto();
}

void UIDebugCPU::on_pbStepOver_clicked()
{
	stepOver();
}

void UIDebugCPU::on_pbStepOut_clicked()
{
	stepOut();
}

void UIDebugCPU::on_pbMemoryTransfer_clicked()
{
	UIMemoryTransfer( mYabauseThread, this ).exec();
}

void UIDebugCPU::on_pbMemoryEditor_clicked()
{	
	UIMemoryEditor( mYabauseThread, this ).exec();
}

void UIDebugCPU::on_pbReserved1_clicked()
{
	reserved1();
}

void UIDebugCPU::on_pbReserved2_clicked()
{
	reserved2();
}

void UIDebugCPU::on_pbReserved3_clicked()
{
	reserved3();
}

void UIDebugCPU::on_pbReserved4_clicked()
{
	reserved4();
}

void UIDebugCPU::on_pbReserved5_clicked()
{
	reserved5();
}

void UIDebugCPU::updateRegList()
{
}

void UIDebugCPU::updateCodeList(u32 addr)
{
}

u32 UIDebugCPU::getRegister(int index, int *size)
{
	*size = 4;
	return 0;
}

void UIDebugCPU::setRegister(int index, u32 value)
{
}

bool UIDebugCPU::addCodeBreakpoint(u32 addr)
{
	return true;
}

void UIDebugCPU::toggleCodeBreakpoint(u32 addr)
{
	QString text;
	text.sprintf("%08X", addr);
	QList<QListWidgetItem *> list = lwCodeBreakpoints->findItems(text, Qt::MatchFixedString);

	if (list.count() >= 1)
	{
		// Remove breakpoint
		QListWidgetItem *item=list.value(0);
		delete item;
		delCodeBreakpoint(addr);
	}
	else
	{
		// Add breakpoint
		if (addCodeBreakpoint(addr))
			lwCodeBreakpoints->addItem(text);
	}
}

bool UIDebugCPU::delCodeBreakpoint(u32 addr)
{
	return true;
}

bool UIDebugCPU::addMemoryBreakpoint(u32 addr, u32 flags)
{
	return true;
}

bool UIDebugCPU::delMemoryBreakpoint(u32 addr)
{
	return true;
}

void UIDebugCPU::stepInto()
{
}

void UIDebugCPU::stepOver()
{
}

void UIDebugCPU::stepOut()
{
}

void UIDebugCPU::reserved1()
{
}

void UIDebugCPU::reserved2()
{
}

void UIDebugCPU::reserved3()
{
}

void UIDebugCPU::reserved4()
{
}

void UIDebugCPU::reserved5()
{
}
