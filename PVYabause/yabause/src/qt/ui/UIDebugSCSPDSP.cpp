/*	Copyright 2015 Theo Berkau <cwx@cyberwarriorx.com>

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
#include "UIDebugSCSPDSP.h"
#include "../CommonDialogs.h"
#include "UIYabause.h"

int SCSPDSPDis(u32 addr, char *string)
{
   ScspDspDisasm((u8)addr, string);
   return 1;
}

void SCSPDSPBreakpointHandler (u32 addr)
{
   UIYabause* ui = QtYabause::mainWindow( false );
}

UIDebugSCSPDSP::UIDebugSCSPDSP( YabauseThread *mYabauseThread, QWidget* p )
	: UIDebugCPU( mYabauseThread, p )
{
   this->setWindowTitle(QtYabause::translate("Debug SCSP DSP"));
   gbRegisters->setTitle(QtYabause::translate("DSP Registers"));
	pbMemoryTransfer->setVisible( true );
	gbMemoryBreakpoints->setVisible( false );

   QSize size = lwRegisters->minimumSize();
   size.setWidth(size.width() + lwRegisters->fontMetrics().averageCharWidth());
   lwRegisters->setMinimumSize(size);

   size = lwDisassembledCode->minimumSize();
   size.setWidth(lwRegisters->fontMetrics().averageCharWidth() * 80);
   lwDisassembledCode->setMinimumSize(size);
   lwDisassembledCode->setDisassembleFunction(SCSPDSPDis);
   lwDisassembledCode->setEndAddress(128);
}

void UIDebugSCSPDSP::updateRegList()
{
}

void UIDebugSCSPDSP::updateCodeList(u32 addr)
{
}

u32 UIDebugSCSPDSP::getRegister(int index, int *size)
{
   *size = 0;
   return 0;
}

void UIDebugSCSPDSP::setRegister(int index, u32 value)
{
}

bool UIDebugSCSPDSP::addCodeBreakpoint(u32 addr)
{
	return true;
}

bool UIDebugSCSPDSP::delCodeBreakpoint(u32 addr)
{
	return true;
}

void UIDebugSCSPDSP::stepInto()
{
}


