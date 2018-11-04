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
#ifndef UIDISASM_H
#define UIDISASM_H

#include <QScrollArea>
#include "../QtYabause.h"

class UIDisasm : public QAbstractScrollArea
{
	Q_OBJECT
public:
	UIDisasm( QWidget* parent = 0 );

   void setSelectionColor(const QColor &color);
   void setDisassembleFunction(int (*func)(u32, char *));
   void setEndAddress(u32 address);
   void goToAddress(u32 address, bool vCenter=true);
   void setPC(u32 address);
   void setMinimumInstructionSize(int instructionSize);
private:
   void adjustSettings();

   int fontWidth, fontHeight;
   QColor selectionColor;

   int (*disassembleFunction)(u32 address, char *string);
   u32 address;
   bool vCenter;
   u32 endAddress;
   u32 pc;
   int instructionSize;

protected:
   void mouseDoubleClickEvent( QMouseEvent * event );
   void paintEvent(QPaintEvent *event);
protected slots:

signals:
      void toggleCodeBreakpoint(u32 addr);
};

#endif // UIDISASM_H
