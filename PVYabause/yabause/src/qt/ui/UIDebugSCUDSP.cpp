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
#include "UIDebugSCUDSP.h"
#include "../CommonDialogs.h"
#include "UIYabause.h"

int SCUDSPDis(u32 addr, char *string)
{
   ScuDspDisasm((u8)addr, string);
   return 1;
}

void SCUDSPBreakpointHandler (u32 addr)
{
   UIYabause* ui = QtYabause::mainWindow( false );

   emit ui->breakpointHandlerSCUDSP();
}

UIDebugSCUDSP::UIDebugSCUDSP( YabauseThread *mYabauseThread, QWidget* p )
	: UIDebugCPU( mYabauseThread, p )
{
   this->setWindowTitle(QtYabause::translate("Debug SCU DSP"));
   gbRegisters->setTitle(QtYabause::translate("DSP Registers"));
	pbMemoryTransfer->setVisible( false );
	gbMemoryBreakpoints->setVisible( false );

   pbReserved1->setText(QtYabause::translate("Save Program"));
   pbReserved2->setText(QtYabause::translate("Save MD0"));
   pbReserved3->setText(QtYabause::translate("Save MD1"));
   pbReserved4->setText(QtYabause::translate("Save MD2"));
   pbReserved5->setText(QtYabause::translate("Save MD3"));

   pbReserved1->setVisible( true );
   pbReserved2->setVisible( true );
   pbReserved3->setVisible( true );
   pbReserved4->setVisible( true );
   pbReserved5->setVisible( true );

   QSize size = lwRegisters->minimumSize();
   size.setWidth(size.width() + lwRegisters->fontMetrics().averageCharWidth());
   lwRegisters->setMinimumSize(size);

   size = lwDisassembledCode->minimumSize();
   size.setWidth(lwRegisters->fontMetrics().averageCharWidth() * 80);
   lwDisassembledCode->setMinimumSize(size);

   updateRegList();
   if (ScuRegs)
   {
      scudspregs_struct regs;
      const scucodebreakpoint_struct *cbp;
      int i;

      cbp = ScuDspGetBreakpointList();

      for (i = 0; i < MAX_BREAKPOINTS; i++)
      {
         QString text;
         if (cbp[i].addr != 0xFFFFFFFF)
         {
            text.sprintf("%08X", (int)cbp[i].addr);
            lwCodeBreakpoints->addItem(text);
         }
      }

      lwDisassembledCode->setDisassembleFunction(SCUDSPDis);
      lwDisassembledCode->setEndAddress(0x100);
      lwDisassembledCode->setMinimumInstructionSize(1);
      ScuDspGetRegisters(&regs);
      updateCodeList(regs.PC);

      ScuDspSetBreakpointCallBack(SCUDSPBreakpointHandler);
   }
}

void UIDebugSCUDSP::updateRegList()
{
   scudspregs_struct regs;
   QString str;

   if (ScuRegs == NULL)
      return;

   memset(&regs, 0, sizeof(regs));
   ScuDspGetRegisters(&regs);
   lwRegisters->clear();

   str.sprintf("PR = %d   EP = %d", regs.ProgControlPort.part.PR, regs.ProgControlPort.part.EP);
   lwRegisters->addItem(str);

   str.sprintf("T0 = %d   S =  %d", regs.ProgControlPort.part.T0, regs.ProgControlPort.part.S);
   lwRegisters->addItem(str);

   str.sprintf("Z =  %d   C =  %d", regs.ProgControlPort.part.Z, regs.ProgControlPort.part.C);
   lwRegisters->addItem(str);

   str.sprintf("V =  %d   E =  %d", regs.ProgControlPort.part.V, regs.ProgControlPort.part.E);
   lwRegisters->addItem(str);

   str.sprintf("ES = %d   EX = %d", regs.ProgControlPort.part.ES, regs.ProgControlPort.part.EX);
   lwRegisters->addItem(str);

   str.sprintf("LE =          %d", regs.ProgControlPort.part.LE);
   lwRegisters->addItem(str);

   str.sprintf("P =          %02X", regs.ProgControlPort.part.P);
   lwRegisters->addItem(str);

   str.sprintf("TOP =        %02X", regs.TOP);
   lwRegisters->addItem(str);

   str.sprintf("LOP =        %02X", regs.LOP);
   lwRegisters->addItem(str);

   str.sprintf("CT = %02X:%02X:%02X:%02X", regs.CT[0], regs.CT[1], regs.CT[2], regs.CT[3]);
   lwRegisters->addItem(str);

   str.sprintf("RA =   %08lX", regs.RA0);
   lwRegisters->addItem(str);

   str.sprintf("WA =   %08lX", regs.WA0);
   lwRegisters->addItem(str);

   str.sprintf("RX =   %08lX", regs.RX);
   lwRegisters->addItem(str);

   str.sprintf("RY =   %08lX", regs.RX);
   lwRegisters->addItem(str);

   str.sprintf("PH =       %04X", regs.P.part.H & 0xFFFF);
   lwRegisters->addItem(str);

   str.sprintf("PL =   %08X", (int)(regs.P.part.L & 0xFFFFFFFF));
   lwRegisters->addItem(str);

   str.sprintf("ACH =      %04X", regs.AC.part.H & 0xFFFF);
   lwRegisters->addItem(str);

   str.sprintf("ACL =  %08X", (int)(regs.AC.part.L & 0xFFFFFFFF));
   lwRegisters->addItem(str);
}

void UIDebugSCUDSP::updateCodeList(u32 addr)
{
   lwDisassembledCode->goToAddress(addr);
   lwDisassembledCode->setPC(addr);
}

u32 UIDebugSCUDSP::getRegister(int index, int *size)
{
   *size = 0;
   return 0;
}

void UIDebugSCUDSP::setRegister(int index, u32 value)
{
}

bool UIDebugSCUDSP::addCodeBreakpoint(u32 addr)
{
   return ScuDspAddCodeBreakpoint(addr) == 0;     
}

bool UIDebugSCUDSP::delCodeBreakpoint(u32 addr)
{
   return ScuDspDelCodeBreakpoint(addr) == 0;
}

void UIDebugSCUDSP::stepInto()
{
   ScuDspStep();
}

void UIDebugSCUDSP::reserved1()
{
   const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if ( !s.isNull() )
      ScuDspSaveProgram(s.toLatin1());
}

void UIDebugSCUDSP::reserved2()
{
   const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if ( !s.isNull() )
      ScuDspSaveMD(s.toLatin1(), 0);
}

void UIDebugSCUDSP::reserved3()
{
   const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if ( !s.isNull() )
      ScuDspSaveMD(s.toLatin1(), 1);
}

void UIDebugSCUDSP::reserved4()
{
   const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if ( !s.isNull() )
      ScuDspSaveMD(s.toLatin1(), 2);
}

void UIDebugSCUDSP::reserved5()
{
   const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if ( !s.isNull() )
      ScuDspSaveMD(s.toLatin1(), 3);
}

