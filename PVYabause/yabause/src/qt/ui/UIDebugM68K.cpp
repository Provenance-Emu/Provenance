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

#include "UIDebugM68K.h"
#include "../CommonDialogs.h"
#include "UIYabause.h"

int M68KDis(u32 addr, char *string)
{
   return (int)(M68KDisasm(addr, string) - addr);
}

void M68KBreakpointHandler (u32 addr)
{
   UIYabause* ui = QtYabause::mainWindow( false );

   emit ui->breakpointHandlerM68K();
}

UIDebugM68K::UIDebugM68K( YabauseThread *mYabauseThread, QWidget* p )
	: UIDebugCPU(mYabauseThread, p )
{
   this->setWindowTitle(QtYabause::translate("Debug M68K"));
   gbRegisters->setTitle(QtYabause::translate("M68K Registers"));
	gbMemoryBreakpoints->setVisible( false );

   updateRegList();
   if (SoundRam)
   {
      m68kregs_struct m68kregs;
      const m68kcodebreakpoint_struct *cbp;
      int i;

      cbp = M68KGetBreakpointList();

      for (i = 0; i < MAX_BREAKPOINTS; i++)
      {
         QString text;
         if (cbp[i].addr != 0xFFFFFFFF)
         {
            text.sprintf("%08X", (int)cbp[i].addr);
            lwCodeBreakpoints->addItem(text);
         }
      }

      lwDisassembledCode->setDisassembleFunction(M68KDis);
      lwDisassembledCode->setEndAddress(0x100000);
      lwDisassembledCode->setMinimumInstructionSize(2);
      M68KGetRegisters(&m68kregs);
      updateCodeList(m68kregs.PC);

      M68KSetBreakpointCallBack(M68KBreakpointHandler);
   }
}

void UIDebugM68K::updateRegList()
{
   int i;
   m68kregs_struct regs;
   QString str;

   if (SoundRam == NULL)
      return;

   memset(&regs, 0, sizeof(regs));
   M68KGetRegisters(&regs);
   lwRegisters->clear();

   // Data registers
   for (i = 0; i < 8; i++)
   {
      str.sprintf("D%d =   %08X", i, (int)regs.D[i]);
      lwRegisters->addItem(str);
   }

   // Address registers
   for (i = 0; i < 8; i++)
   {
      str.sprintf("A%d =   %08X", i, (int)regs.A[i]);
      lwRegisters->addItem(str);
   }

   // SR
   str.sprintf("SR =   %08X", (int)regs.SR);
   lwRegisters->addItem(str);

   // PC
   str.sprintf("PC =   %08X", (int)regs.PC);
   lwRegisters->addItem(str);
}

void UIDebugM68K::updateCodeList(u32 addr)
{
   lwDisassembledCode->goToAddress(addr);
   lwDisassembledCode->setPC(addr);
}

u32 UIDebugM68K::getRegister(int index, int *size)
{
   m68kregs_struct m68kregs;
   u32 value;

   M68KGetRegisters(&m68kregs);

   switch (index)
   {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
         value = m68kregs.D[index];                           
         break;
      case 8:
      case 9:
      case 10:
      case 11:
      case 12:
      case 13:
      case 14:
      case 15:
         value = m68kregs.A[index - 8];
         break;
      case 16:
         value = m68kregs.SR;
         break;
      case 17:
         value = m68kregs.PC;
         break;
      default: break;
   }

   *size = 4;
   return value;
}

void UIDebugM68K::setRegister(int index, u32 value)
{
   m68kregs_struct m68kregs;

   switch (index)
   {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
         m68kregs.D[index] = value;
         break;
      case 8:
      case 9:
      case 10:
      case 11:
      case 12:
      case 13:
      case 14:
      case 15:
         m68kregs.A[index - 8] = value;
         break;
      case 16:
         m68kregs.SR = value;
         break;
      case 17:
         m68kregs.PC = value;
         updateCodeList(m68kregs.PC);
         break;
      default: break;
   }

   M68KSetRegisters(&m68kregs);
}

bool UIDebugM68K::addCodeBreakpoint(u32 addr)
{
   return M68KAddCodeBreakpoint(addr) == 0;     
}

bool UIDebugM68K::delCodeBreakpoint(u32 addr)
{
    return M68KDelCodeBreakpoint(addr) == 0;
}

void UIDebugM68K::stepInto()
{
   if (M68K)
      M68KStep();
}
