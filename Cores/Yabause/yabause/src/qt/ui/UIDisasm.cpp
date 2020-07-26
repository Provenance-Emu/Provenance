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
#include "UIDisasm.h"

#include <QPainter>
#include <QPaintEvent>
#include <QScrollBar>

int DisasmInstructionNull(u32 address, char *string)
{
   strcpy(string, " ");
   return 0;
}

UIDisasm::UIDisasm( QWidget* p )
	: QAbstractScrollArea( p )
{
   disassembleFunction = DisasmInstructionNull;
   address = 0;
   pc = 0xFFFFFFFF;
   instructionSize = 1;

   setSelectionColor(QColor(0x6d, 0x9e, 0xff, 0xff));

   adjustSettings();
}

void UIDisasm::setSelectionColor(const QColor &color)
{
   selectionColor = color;
   viewport()->update();
}

void UIDisasm::setDisassembleFunction(int (*func)(u32, char *))
{
   disassembleFunction = func;
}

void UIDisasm::setEndAddress(u32 address)
{
   endAddress = address;
   adjustSettings();
}

void UIDisasm::goToAddress(u32 address, bool vCenter)
{
   this->address = address;
   this->vCenter = vCenter;
   int height = viewport()->height();
   verticalScrollBar()->setValue(address);
   viewport()->update();
}

void UIDisasm::setPC(u32 address)
{
   this->pc = address;
}

void UIDisasm::setMinimumInstructionSize(int instructionSize)
{
   this->instructionSize = instructionSize;
   adjustSettings();
}

void UIDisasm::adjustSettings()
{
   verticalScrollBar()->setRange(0, endAddress);
   verticalScrollBar()->setSingleStep(instructionSize);

   fontWidth = fontMetrics().width(QLatin1Char('9'));
   fontHeight = fontMetrics().height();

   viewport()->update();
}

void UIDisasm::mouseDoubleClickEvent( QMouseEvent * event )
{
   if (event->button() == Qt::LeftButton)
   {
      // Calculate address
      QPoint pos = event->pos();
      QRect viewportPos = viewport()->rect();
      int top = viewportPos.top();
      int bottom = viewportPos.bottom();
      int posy = pos.y();
      int line = posy / fontHeight;

      int offset=0;
      int scroll_pos=verticalScrollBar()->value();
      int currentAddress=scroll_pos/instructionSize*instructionSize;
      for (int i = 0; i != line; i++)
      {
         char text[256];
         offset += disassembleFunction(currentAddress, text);
      }


      emit toggleCodeBreakpoint(currentAddress+offset);
   }
}

void UIDisasm::paintEvent(QPaintEvent *event)
{
   QPainter painter(viewport());   

   // calc position
   int top = event->rect().top();
   int bottom = event->rect().bottom();

   verticalScrollBar()->setPageStep(bottom/fontHeight*instructionSize);

   int pos=verticalScrollBar()->value();
   int xPos = 2;
   int yPosStart = top + fontHeight;

   QBrush selected = QBrush(selectionColor);
   QPen colSelected = QPen(Qt::white);
   QPen colSelected2 = QPen(selectionColor);

   int currentAddress=pos/instructionSize*instructionSize;
   for (int yPos = yPosStart; yPos < bottom; )
   {
      char text[256];
      int offset = disassembleFunction(currentAddress, text);
      QString disText(text);

      if (currentAddress == pc && pc != 0xFFFFFFFF)
      {
         int ascent = fontMetrics().ascent();

         painter.setBackground(selected);
         painter.setBackgroundMode(Qt::OpaqueMode);
         painter.setPen(colSelected2);
         painter.drawRect(0, yPos-ascent, event->rect().width(), fontHeight);
         painter.fillRect(0, yPos-ascent, event->rect().width(), fontHeight, selected);

         painter.setBackgroundMode(Qt::TransparentMode);
         painter.setPen(colSelected);         
         painter.setPen(this->palette().color(QPalette::WindowText));
         painter.drawText(xPos, yPos-ascent, event->rect().width(), ascent, Qt::AlignJustify, disText);
      }
      else
      {
         painter.setPen(this->palette().color(QPalette::WindowText));
         painter.setBackgroundMode(Qt::TransparentMode);
         painter.drawText(xPos, yPos, disText);
      }

      currentAddress += offset;
      yPos += fontHeight;
   }
}
