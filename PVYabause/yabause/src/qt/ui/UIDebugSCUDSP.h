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
#ifndef UIDEBUGSCUDSP_H
#define UIDEBUGSCUDSP_H

#include "UIDebugCPU.h"
#include "../QtYabause.h"

class UIDebugSCUDSP : public UIDebugCPU
{
	Q_OBJECT
private:

public:
	UIDebugSCUDSP( YabauseThread *mYabauseThread, QWidget* parent = 0 );
   void updateRegList();
   void updateCodeList(u32 addr);
   u32 getRegister(int index, int *size);
   void setRegister(int index, u32 value);
   bool addCodeBreakpoint(u32 addr);
   bool delCodeBreakpoint(u32 addr);
   void stepInto();
   void reserved1();
   void reserved2();
   void reserved3();
   void reserved4();
   void reserved5();
protected:

protected slots:
};

#endif // UIDEBUGSCUDSP_H
