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
#include "UIHexEditor.h"
#include <QApplication>
#include <QClipboard>
#include <QPainter>
#include <QPaintEvent>
#include <QScrollBar>

UIHexEditor::UIHexEditor( QWidget* p )
{
   QList<QString> tabList;
   QList<u32> startList;
   QList<u32> endList;
   tabList   << "All"      << "BIOS"     << "LWRAM"    << "HWRAM"     << 
                "CS0"      << "CS1"      << "CS2"      << "68K RAM"   << 
                "VDP1 RAM" << "VDP1 FB"  << "VDP2 RAM" << "VDP2 CRAM";
   startList << 0x00000000 << 0x00000000 << 0x00200000 << 0x06000000 <<
                0x02000000 << 0x04000000 << 0x05800000 << 0x05A00000 <<
                0x05C00000 << 0x05C80000 << 0x05E00000 << 0x05F00000;
   endList   << 0xFFFFFFFF << 0x0017FFFF << 0x002FFFFF << 0x060FFFFF <<
                0x03FFFFFF << 0x04FFFFFF << 0x058FFFFF << 0x05AFFFFF <<
                0x05C7FFFF << 0x05CFFFFF << 0x05EFFFFF << 0x05F7FFFF;
   for (int i=0; i < tabList.count(); i++)
   {
      UIHexEditorWnd *hexEditorWnd = new UIHexEditorWnd (this);
      hexEditorWnd->setStartAddress(startList[i]);
      hexEditorWnd->setEndAddress(endList[i]);
      addTab(hexEditorWnd, tabList[i]);
   }
   setTabPosition(QTabWidget::South);
}

void UIHexEditor::goToAddress( u32 address, bool setCursor )
{
   UIHexEditorWnd *hexEditorWnd=(UIHexEditorWnd *)currentWidget();
   hexEditorWnd->goToAddress(address, setCursor);
}

u32 UIHexEditor::getStartAddress()
{
   UIHexEditorWnd *hexEditorWnd=(UIHexEditorWnd *)currentWidget();
   return hexEditorWnd->getStartAddress();
}

u32 UIHexEditor::getEndAddress()
{
   UIHexEditorWnd *hexEditorWnd=(UIHexEditorWnd *)currentWidget();
   return hexEditorWnd->getEndAddress();
}

bool UIHexEditor::saveSelected( QString filename )
{
   UIHexEditorWnd *hexEditorWnd=(UIHexEditorWnd *)currentWidget();
   return hexEditorWnd->saveSelected(filename);
}

UIHexEditorWnd::UIHexEditorWnd( QWidget* p )
	: QAbstractScrollArea( p )
{
   gapSizeAddrHex = 10;
   gapSizeHexText = 16;
   bytesPerLine = 16;
   bytesPerGroup = 2;
   nibblesPerGroup = bytesPerGroup * 2;
   hexCharsInLine = bytesPerLine * 2 + (bytesPerLine / bytesPerGroup) - 1;

   textEdit = false;
   setStartAddress(0);
   setEndAddress(0xFFFFFFFF);
   setAddrAreaColor(this->palette().color(QPalette::AlternateBase));
   adjustSettings();
   resetSelection(0);
   goToAddress(0);

   connect(verticalScrollBar(), SIGNAL(valueChanged(int)), this, SLOT(sliderUpdate(int)));

   connect(&cursorTimer, SIGNAL(timeout()), this, SLOT(updateCursor()));
   cursorTimer.setInterval(500);
   cursorTimer.start();

   connect(&autoScrollTimer, SIGNAL(timeout()), this, SLOT(autoScroll()));
   autoScrollTimer.setInterval(5);

   setMouseTracking(true);
}


void UIHexEditorWnd::sliderUpdate(int value)
{
   setCursorPos(cursorAddr);
}

void UIHexEditorWnd::setAddrAreaColor(const QColor &color)
{
   addrAreaColor = color;
   viewport()->update();
}

void UIHexEditorWnd::setStartAddress(u32 address)
{
   startAddress = address;
   adjustSettings();
}

u32 UIHexEditorWnd::getStartAddress()
{
   return startAddress;
}

void UIHexEditorWnd::setEndAddress(u32 address)
{
   endAddress = address;
   adjustSettings();
}

u32 UIHexEditorWnd::getEndAddress()
{
   return endAddress;
}

u32 UIHexEditorWnd::getAddress()
{
   return cursorAddr;
}

void UIHexEditorWnd::setFont(const QFont &font)
{
   QWidget::setFont(font);
   adjustSettings();
   setCursorPos(cursorAddr);
}

void UIHexEditorWnd::goToAddress(u32 address, bool setCursor)
{
   int height = viewport()->height();
   verticalScrollBar()->setValue(address/bytesPerLine);
   adjustSettings();
   if (setCursor)
   {
      setCursorPos(address * 2);
      resetSelection(address * 2);
   }
   viewport()->update();
}

void UIHexEditorWnd::clear(u32 index, int len)
{
   for (int i=0; i < len; i++)
      MappedMemoryWriteByte(index+i, 0);
}

void UIHexEditorWnd::overwrite(s64 index, char ch)
{
   u8 data = MappedMemoryReadByte(index / 2);
   char str[2] = { ch, '\0' };
   ch = strtol(str, NULL, 16);
   if (index % 2 == 0)
      MappedMemoryWriteByte(index / 2, data & 0xF | (ch << 4));
   else
      MappedMemoryWriteByte(index / 2, data & 0xF0 | ch);
   resetSelection();
}

void UIHexEditorWnd::overwrite(u32 addr, u8 data)
{
   MappedMemoryWriteByte(addr, data);
   resetSelection();
}

void UIHexEditorWnd::updateCursor()
{
   if (blinkCursor)
      blinkCursor = false;
   else
      blinkCursor = true;
   viewport()->update();
}

void UIHexEditorWnd::autoScroll()
{
   s64 actPos = cursorPos(autoScrollDragPos, false);

   if (actPos < 0)
   {
      // Check to see if we can scroll up or down
      actPos = (s64)(((autoScrollDragPos.y() - 3) / fontHeight) + (s64)verticalScrollBar()->value()) * 2 * (s64)bytesPerLine;
   }

   if (autoScrollDir == -1)
      // Scroll Up
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepSub);

   if (autoScrollDir == 1)
      // Scroll Down
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepAdd);

   // Adjust cursor/selection position
   setCursorPos(actPos & ~1);
   setSelection(actPos & ~1);
}

void UIHexEditorWnd::adjustSettings()
{
   QSize size = this->size();
   QSize areaSize = viewport()->size();
   int fontSize = fontMetrics().height();

   fontAscent = fontMetrics().ascent();
   fontWidth = fontMetrics().width(QLatin1Char('9'));
   fontHeight = fontMetrics().height();

   verticalScrollBar()->setRange(startAddress / bytesPerLine, (endAddress / bytesPerLine) - (areaSize.height() / fontHeight) + 1);
   verticalScrollBar()->setSingleStep(1);
   verticalScrollBar()->setPageStep(areaSize.height()/fontHeight);

   headerHeight = fontHeight;
   yPosEdit = fontHeight + (fontHeight / 8);
   posAddr = 0;
   posHex = 8 * fontWidth + gapSizeAddrHex;
   posText = posHex + hexCharsInLine * fontWidth + gapSizeHexText;

   setCursorPos(cursorAddr);
   viewport()->update();
}

void UIHexEditorWnd::keyPressCursor(QKeyEvent *event)
{
   if (event->matches(QKeySequence::MoveToNextChar))
   {
      if (cursorY + (fontHeight*2) > viewport()->height() &&
         (cursorAddr + 2) % (bytesPerLine * 2) == 0)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepAdd);

      setCursorPos((cursorAddr & ~1) + 2);
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToPreviousChar))
   {
      if (cursorAddr <= (s64)verticalScrollBar()->value() * bytesPerLine * 2)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepSub);
      if (cursorAddr-startAddress < 2)
         setCursorPos(startAddress);
      else
         setCursorPos((cursorAddr & ~1) - 2);
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToEndOfLine))
   {
      setCursorPos((cursorAddr & ~1) | (2 * bytesPerLine -2));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToStartOfLine))
   {
      setCursorPos((cursorAddr & ~1) - (cursorAddr % (2 * bytesPerLine)));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToPreviousLine))
   {
      if (cursorAddr <= (s64)verticalScrollBar()->value() * bytesPerLine * 2)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepSub);
      if (cursorAddr-startAddress < (2 * bytesPerLine))
         setCursorPos(startAddress);
      else
         setCursorPos((cursorAddr & ~1) - (2 * bytesPerLine));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToNextLine))
   {
      if (cursorY + (fontHeight*2) > viewport()->height())
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepAdd);
      setCursorPos((cursorAddr & ~1) + (2 * bytesPerLine));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToNextPage))
   {
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderPageStepAdd);
      setCursorPos((cursorAddr & ~1) + (verticalScrollBar()->pageStep() * 2 * bytesPerLine));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToPreviousPage))
   {
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderPageStepSub);
      setCursorPos((cursorAddr & ~1) - (verticalScrollBar()->pageStep() * 2 * bytesPerLine));
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToEndOfDocument))
   {
      setCursorPos(endAddress * 2);
      resetSelection(cursorAddr);
   }
   if (event->matches(QKeySequence::MoveToStartOfDocument))
   {
      setCursorPos(startAddress);
      resetSelection(cursorAddr);
   }
}

void UIHexEditorWnd::keyPressSelect(QKeyEvent *event)
{
   if (event->matches(QKeySequence::SelectAll))
   {
      resetSelection(0);
      setSelection(2*endAddress + 1);
   }
   if (event->matches(QKeySequence::SelectNextChar))
   {
      if (cursorY + (fontHeight*2) > viewport()->height() &&
         (cursorAddr + 2) % (bytesPerLine * 2) == 0)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepAdd);
      s64 pos = (cursorAddr & ~1) + 2;
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectPreviousChar))
   {
      if (cursorAddr <= (s64)verticalScrollBar()->value() * bytesPerLine * 2)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepSub);
      s64 pos = (cursorAddr & ~1) - 2;
      setSelection(pos);
      setCursorPos(pos);
   }
   if (event->matches(QKeySequence::SelectEndOfLine))
   {
      s64 pos = (cursorAddr & ~1) - (cursorAddr % (2 * bytesPerLine)) + (2 * bytesPerLine);
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectStartOfLine))
   {
      s64 pos = (cursorAddr & ~1) - (cursorAddr % (2 * bytesPerLine));
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectPreviousLine))
   {
      if (cursorAddr <= (s64)verticalScrollBar()->value() * bytesPerLine * 2)
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepSub);
      s64 pos = (cursorAddr & ~1) - (2 * bytesPerLine);
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectNextLine))
   {
      if (cursorY + (fontHeight*2) > viewport()->height())
         verticalScrollBar()->triggerAction(QAbstractSlider::SliderSingleStepAdd);
      s64 pos = (cursorAddr & ~1) + (2 * bytesPerLine);
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectNextPage))
   {
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderPageStepAdd);
      s64 pos = (cursorAddr & ~1) + (verticalScrollBar()->pageStep() * 2 * bytesPerLine);
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectPreviousPage))
   {
      verticalScrollBar()->triggerAction(QAbstractSlider::SliderPageStepSub);
      int pos = (cursorAddr & ~1) - (verticalScrollBar()->pageStep() * 2 * bytesPerLine);
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectEndOfDocument))
   {
      int pos = endAddress * 2;
      setCursorPos(pos);
      setSelection(pos);
   }
   if (event->matches(QKeySequence::SelectStartOfDocument))
   {
      int pos = 0;
      setCursorPos(pos);
      setSelection(pos);
   }
}

void UIHexEditorWnd::keyPressEdit(QKeyEvent *event, u64 posAddr)
{
   int key = int(event->text()[0].toLatin1());
   if (textEdit)
   {
      if ((key>='0' && key<='9') || (key>='a' && key <= 'z') || (key>='A' && key <= 'Z'))
      {
         if (getSelectionStart() != getSelectionEnd())
         {
            posAddr = getSelectionStart();
            clear(posAddr, getSelectionEnd() - posAddr);
            setCursorPos(2*posAddr);
            resetSelection(2*posAddr);
         }

         // Patch byte
         overwrite((u32)cursorAddr >> 1, (u8)key);
         setCursorPos(cursorAddr + 2);
         resetSelection(cursorAddr);
      }
   }
   else
   {
      if ((key>='0' && key<='9') || (key>='a' && key <= 'f') || (key>='A' && key <= 'F'))
      {
         if (getSelectionStart() != getSelectionEnd())
         {
            posAddr = getSelectionStart();
            clear(posAddr, getSelectionEnd() - posAddr);
            setCursorPos(2*posAddr);
            resetSelection(2*posAddr);
         }

         // Patch byte
         overwrite((s64)cursorAddr, (char)key);
         setCursorPos(cursorAddr + 1);
         resetSelection(cursorAddr);
      }
   }
   if (event->key()==Qt::Key_Tab)
   {
      textEdit ^= true;
   }
   if (event->matches(QKeySequence::Copy))
   {
      QString result = QString();
      if (!textEdit)
      {
         for (u64 idx = getSelectionStart(); idx < getSelectionEnd(); idx++)
            result.append(QString("%1").arg(MappedMemoryReadByte(idx), 2, 16, QChar('0')).toUpper());
      }
      else
      {
         for (u64 idx = getSelectionStart(); idx < getSelectionEnd(); idx++)
            result.append((char)MappedMemoryReadByte(idx));
      }
      QClipboard *clipboard = QApplication::clipboard();
      clipboard->setText(result);
   }
   if (event->matches(QKeySequence::Paste))
   {
      QClipboard *clipboard = QApplication::clipboard();
      QString text = clipboard->text().toLatin1();
      if (!textEdit)
      {
         for (int i = 0; i < text.length(); i++)
            overwrite(cursorAddr+i, text[i].toLatin1());
      }
      else
      {
         for (int i = 0; i < text.length(); i++)
            overwrite((u32)(cursorAddr/2), (u8)text[i].toLatin1());
      }
      setCursorPos(cursorAddr + 2 * text.length());
      resetSelection(getSelectionStart());
   }
   if (event->matches(QKeySequence::Delete))
   {
      if (getSelectionStart() != getSelectionEnd())
      {
         posAddr = getSelectionStart();
         clear(posAddr, getSelectionEnd() - posAddr);
         setCursorPos(2*posAddr);
         resetSelection(2*posAddr);
      }
      else
      {
         overwrite(posAddr, char(0));
      }
   }
   if ((event->key() == Qt::Key_Backspace) && (event->modifiers() == Qt::NoModifier))
   {
      if (getSelectionStart() != getSelectionEnd())
      {
         posAddr = getSelectionStart();
         clear(posAddr, getSelectionEnd() - posAddr);
         setCursorPos(2*posAddr);
         resetSelection(2*posAddr);
      }
      else
      {
         if (posAddr > 0)
         {
            overwrite(posAddr - 1, char(0));
            setCursorPos(cursorAddr - 2);
         }
      }
   }
}

void UIHexEditorWnd::keyPressEvent(QKeyEvent *event)
{
   int posX;
   if (!textEdit)
   {
      int charX = (cursorX - posHex) / fontWidth;
      posX = (charX / 3) * 2 + (charX % 3);
   }
   else
      posX = (cursorTextX - posText) / fontWidth * 2;
   u64 posAddr = verticalScrollBar()->value() * bytesPerLine + (cursorY / fontHeight) * bytesPerLine + posX / 2;

   keyPressCursor(event);
   keyPressSelect(event);
   keyPressEdit(event, posAddr);

   viewport()->update();
}

void UIHexEditorWnd::mouseMoveEvent(QMouseEvent * event)
{
   s64 hoverPos = cursorPos(event->pos(), false);
   if (hoverPos >= 0)
      setHoverPos(hoverPos);

   if (event->buttons() & Qt::LeftButton)
   {
      QPoint pos=event->pos();
      blinkCursor = false;
      viewport()->update();
      s64 actPos = cursorPos(pos);
      
      if (viewport()->rect().contains(pos))
         autoScrollTimer.stop();
      else if (!autoScrollTimer.isActive())
      {
         if (actPos < 0)
            autoScrollDir = -1;
         else
            autoScrollDir = 1;
         autoScrollDragPos = pos;
         autoScrollTimer.start();
      }

      setCursorPos(actPos & ~1);
      setSelection(actPos & ~1);
   }
   else
   {
      QPoint pos=event->pos();
      QRect hexRect = QRect(posHex, yPosEdit, hexCharsInLine * fontWidth, viewport()->rect().height());
      QRect textRect = QRect(posText, yPosEdit, viewport()->rect().width(), viewport()->rect().height());

      if (hexRect.contains(pos) || textRect.contains(pos))
         viewport()->setCursor(Qt::IBeamCursor);
      else
         viewport()->setCursor(QCursor(Qt::ArrowCursor));
   }
}

void UIHexEditorWnd::mousePressEvent(QMouseEvent * event)
{
   blinkCursor = false;
   viewport()->update();
   s64 cPos = cursorPos(event->pos());
   resetSelection(cPos);
   setCursorPos(cPos & ~1);
}

void UIHexEditorWnd::mouseReleaseEvent(QMouseEvent * event)
{
   autoScrollTimer.stop();
}

void UIHexEditorWnd::drawHeaderArea(QPainter *painter, int left, int top, int right)
{
   int posX = (cursorTextX - posText) / fontWidth;

   painter->fillRect(QRect(left, top, right, headerHeight), addrAreaColor);
   for (int i = 0; i < (bytesPerLine / bytesPerGroup); i++)
   {
      int linePos;
      if (i == 0)
         linePos = posHex - (gapSizeAddrHex / 2) + (i * ((bytesPerGroup * 2)+1) * fontWidth);
      else
         linePos = posHex - (fontWidth / 2) + (i * ((bytesPerGroup * 2)+1) * fontWidth) - 1;
      painter->setPen(Qt::gray);
      painter->drawLine(linePos, top, linePos, headerHeight-1);
      painter->setPen(Qt::white);
      painter->drawLine(linePos+1, top, linePos+1, headerHeight-1);

      int hexOffset = posHex + (i * ((bytesPerGroup * 2)+1) * fontWidth);
      for (int j = 0; j < bytesPerGroup; j++)
      {
         int offset=i * 2 + j;
         if (offset == posX)
         {
            painter->setPen(colHighlighted);
            painter->fillRect(QRect(hexOffset, top, fontWidth*2, fontHeight), highLighted);
         }
         else
            painter->setPen(textColor);
         if (offset == hoverX)
            painter->fillRect(QRect(hexOffset, top, fontWidth*2, fontHeight), highLighted);
         if (offset < 0x10)
         {
            QString text=QString("%1").arg(offset, 1, 16, QChar('0')).toUpper();
            painter->drawText(hexOffset + (fontWidth / 2), top+fontAscent, text);
         }
         else
         {
            QString text=QString("%1").arg(offset, 2, 16, QChar('0')).toUpper();
            painter->drawText(hexOffset, top+fontAscent, text);
         }
         hexOffset += (fontWidth * 2);
      }
   }

   int linePos = posText - (gapSizeHexText / 2);
   painter->setPen(Qt::gray);
   painter->drawLine(linePos, top, linePos, headerHeight-1);
   painter->setPen(Qt::white);
   painter->drawLine(linePos+1, top, linePos+1, headerHeight-1);

   int xPosAscii=posText;
   top += fontAscent;
   for (int i = 0; i < bytesPerLine; i++)
   {
      if (i == posX)
      {
         painter->setPen(colHighlighted);
         painter->fillRect(QRect(xPosAscii, top-fontAscent, fontWidth, fontHeight), highLighted);
      }
      else
         painter->setPen(textColor);
      if (i == hoverX)
         painter->fillRect(QRect(xPosAscii, top-fontAscent, fontWidth, fontHeight), highLighted);
      QString text=QString("%1").arg(i, 1, 16, QChar('0')).toUpper();
      painter->drawText(xPosAscii, top, text);
      xPosAscii += fontWidth;
   }
}

void UIHexEditorWnd::drawAddressArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr)
{
   u32 posBa = ((cursorY - yPosEdit) / fontHeight) * bytesPerLine;

   painter->fillRect(QRect(posAddr, yPosStart-fontHeight, posHex - (gapSizeAddrHex / 2), height()), addrAreaColor);

   // Paint address area
   for (u32 lineIdx = firstLineIdx, yPos = yPosStart; lineIdx < lastLineIdx; lineIdx += bytesPerLine, yPos +=fontHeight)
   {
      if (posBa == lineIdx)
      {
         painter->setPen(colHighlighted);         
         painter->fillRect(QRect(posAddr, yPos-fontAscent, posHex - (gapSizeAddrHex / 2), fontHeight), highLighted);
      }
      else
         painter->setPen(textColor);

      if (hoverY == lineIdx)
         painter->fillRect(QRect(posAddr, yPos-fontAscent, posHex - (gapSizeAddrHex / 2), fontHeight), highLighted);

      QString address = QString("%1")
         .arg(lineIdx + addr , 8, 16, QChar('0')).toUpper();
      painter->drawText(posAddr, yPos, address);
      if (lineIdx+addr >= endAddress+1-bytesPerLine)
         break;
   }
}

void UIHexEditorWnd::drawHexArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr)
{
   painter->setBackgroundMode(Qt::TransparentMode);

   if (this->isEnabled())
   {
      for (u32 lineIdx = firstLineIdx, yPos = yPosStart; lineIdx < lastLineIdx; lineIdx += bytesPerLine, yPos += fontHeight)
      {
         int xPos = posHex;
         for (int colIdx = 0; ((lineIdx + colIdx) < endAddress && (colIdx < bytesPerLine)); colIdx++)
         {
            u32 posBa = addr + lineIdx + colIdx;
            if ((getSelectionStart() <= posBa) && (getSelectionEnd() > posBa))
            {
               painter->setBackground(selected);
               painter->setBackgroundMode(Qt::OpaqueMode);
               painter->setPen(colSelected);
            }
            else
            {
               if (colIdx % (bytesPerGroup * 2) <= bytesPerGroup-1)
               {
                  painter->setPen(textColor);
                  painter->setBackgroundMode(Qt::TransparentMode);
               }
               else
               {
                  painter->setPen(textColorAlt);
                  painter->setBackgroundMode(Qt::TransparentMode);
               }
            }

            QString text;

            // Paint space
            if (colIdx != 0 && colIdx % bytesPerGroup == 0)
            {
               Qt::BGMode oldBackgroundMode = painter->backgroundMode();
               if ((getSelectionStart() == posBa))
                  painter->setBackgroundMode(Qt::TransparentMode);
               painter->drawText(xPos, yPos, QString(" "));
               xPos += fontWidth;
               painter->setBackgroundMode(oldBackgroundMode);
            }

            // Paint hex value
            text=QString("%1").arg(MappedMemoryReadByte(addr + lineIdx + colIdx - firstLineIdx), 2, 16, QChar('0')).toUpper();               
            painter->drawText(xPos, yPos, text);
            xPos += text.length() * fontWidth;
         }

         if (lineIdx+addr >= endAddress+1-bytesPerLine)
            break;
      }
   }
}

void UIHexEditorWnd::drawTextArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr)
{
   if (isEnabled())
   {
      // Paint ascii area
      for (u32 lineIdx = firstLineIdx, yPos = yPosStart; lineIdx < lastLineIdx; lineIdx += bytesPerLine, yPos += fontHeight)
      {
         int xPosAscii = posText;
         for (int colIdx = 0; ((lineIdx + colIdx) < endAddress && (colIdx < bytesPerLine)); colIdx++)
         {

            u32 posBa = addr + lineIdx + colIdx;
            if ((getSelectionStart() <= posBa) && (getSelectionEnd() > posBa))
            {
               painter->setBackground(selected);
               painter->setBackgroundMode(Qt::OpaqueMode);
               painter->setPen(colSelected);
            }
            else
            {
               painter->setPen(this->palette().color(QPalette::WindowText));
               painter->setBackgroundMode(Qt::TransparentMode);
            }

            QString text=QString((char)MappedMemoryReadByte(addr + lineIdx + colIdx));

            if (fontMetrics().width(text) == 0)
               text = QString('.');

            painter->drawText(xPosAscii, yPos, text);
            xPosAscii += fontWidth;
         }
         if (lineIdx+addr >= endAddress+1-bytesPerLine)
            break;
      }
   }
}

void UIHexEditorWnd::paintEvent(QPaintEvent *event)
{
   QPainter painter(viewport());   
   int bottom = event->rect().bottom();
   int pos=verticalScrollBar()->value();

   highLighted = QBrush(Qt::lightGray);
   selected = QBrush(Qt::blue);
   textColor= QPen(Qt::darkGray);
   textColorAlt= QPen(Qt::darkBlue);
   colHighlighted = QPen(Qt::blue);
   colSelected = QPen(Qt::white);

   painter.fillRect(event->rect(), this->palette().color(QPalette::Base));

   int yPos = event->rect().top();

   // Draw header
   drawHeaderArea(&painter, event->rect().left(), event->rect().top(), event->rect().right());

   painter.setPen(Qt::gray);
   int linePos = posText - (gapSizeHexText / 2);
   painter.drawLine(linePos, yPosEdit, linePos, height());
   linePos = posHex - (gapSizeAddrHex / 2);
   painter.drawLine(linePos, yPosEdit, linePos, height());

   // Calc positions
   u32 firstLineIdx = 0;
   u32 lastLineIdx;
   if (isEnabled())
   {
      lastLineIdx = ((event->rect().bottom() / fontHeight) + fontHeight) * bytesPerLine;
      if (lastLineIdx > endAddress)
         lastLineIdx = endAddress;
   }
   else
      lastLineIdx = 1;
   int yPosStart = ((firstLineIdx) / bytesPerLine) * fontHeight + (fontHeight * 2) + (fontHeight / 8);

   u32 addr=pos * bytesPerLine;

   // Paint address area
   drawAddressArea(&painter, firstLineIdx, lastLineIdx, yPosStart, addr);

   // Paint hex area
   drawHexArea(&painter, firstLineIdx, lastLineIdx, yPosStart, addr);

   // Paint text area
   drawTextArea(&painter, firstLineIdx, lastLineIdx, yPosStart, addr);

   bool focus = hasFocus();

   // Paint hex cursor
   if (!hasFocus() || textEdit)
      painter.fillRect(cursorX, cursorY + fontHeight - 2, fontWidth * 2, 2, this->palette().color(QPalette::WindowText));
   else if (blinkCursor && selEnd-selStart == 0)
      painter.fillRect(cursorX, cursorY, 2, fontAscent, this->palette().color(QPalette::WindowText));

   if (!hasFocus() || !textEdit)
      painter.fillRect(cursorTextX, cursorTextY + fontHeight - 2, fontWidth, 2, this->palette().color(QPalette::WindowText));
   else if (blinkCursor && selEnd-selStart == 0)
      painter.fillRect(cursorTextX, cursorTextY, 2, fontAscent, this->palette().color(QPalette::WindowText));
}

void UIHexEditorWnd::resizeEvent(QResizeEvent * event)
{
   adjustSettings();
}

bool UIHexEditorWnd::focusNextPrevChild(bool next)
{
   return false;
}

void UIHexEditorWnd::setCursorPos(s64 position)
{
   // Remove old cursor
   blinkCursor = false;
   viewport()->update();

   // Make sure cursor is in range
   if (position > ((s64)endAddress * 2))
      position = (s64)endAddress * 2;

   if (position < (startAddress *2))
      position = startAddress *2;

   // Recalc position
   cursorAddr = position;
   position -= ((s64)verticalScrollBar()->value() * (s64)bytesPerLine * 2);
   cursorY = yPosEdit + (position / (2 * bytesPerLine)) * fontHeight + 4;
   cursorTextY = cursorY;
   int x = (position % (2 * bytesPerLine));
   cursorX = posHex + ((((x / nibblesPerGroup) * (nibblesPerGroup+1)) + (x % nibblesPerGroup)) * fontWidth );
   cursorTextX = posText + (x / 2) * fontWidth;

   // Time to redraw cursor
   blinkCursor = true;
   viewport()->update();
   //emit currentAddressChanged(cursorAddr/2);
}

void UIHexEditorWnd::setHoverPos(s64 position)
{
   // Make sure cursor is in range
   if (position > ((s64)endAddress * 2))
      position = (s64)endAddress * 2;

   if (position < (startAddress *2))
      position = startAddress *2;

   // Recalc position
   position -= ((s64)verticalScrollBar()->value() * (s64)bytesPerLine * 2);
   hoverY = (position / (2 * bytesPerLine)) * bytesPerLine;
   hoverX = (position % (2 * bytesPerLine)) / 2;

   viewport()->update();
}

s64 UIHexEditorWnd::cursorPos(QPoint pos, bool toggleTextEdit)
{
   s64 result = -1;

   // find char under cursor
   if ((pos.x() >= posHex) && (pos.x() < (posHex + hexCharsInLine * fontWidth)) && pos.y() >= yPosEdit)
   {
      s64 x = (pos.x() - posHex) / fontWidth;

      if ((x % (nibblesPerGroup+1)) == 0)
         x = (x / (nibblesPerGroup+1)) * nibblesPerGroup;
      else
         x = ((x / (nibblesPerGroup+1)) * nibblesPerGroup) + (x % (nibblesPerGroup+1));
      s64 y = (s64)(((pos.y() - yPosEdit - 3) / fontHeight) + (s64)verticalScrollBar()->value()) * 2 * (s64)bytesPerLine;
      result = x + y;
      if (toggleTextEdit)
         textEdit = false;
   }
   else if ((pos.x() >= posText) && (pos.x() < (posText + (bytesPerLine+1) * fontWidth)) && pos.y() >= yPosEdit)
   {
      s64 x = (pos.x() - posText) / fontWidth * 2;
      s64 y = (s64)(((pos.y() - yPosEdit - 3) / fontHeight) + (s64)verticalScrollBar()->value()) * 2 * (s64)bytesPerLine;
      result = x + y;
      if (toggleTextEdit)
         textEdit = true;
   }
   return result;
}

s64 UIHexEditorWnd::cursorPos()
{
   return cursorAddr;
}

void UIHexEditorWnd::resetSelection()
{
   selStart = selFirst;
   selEnd = selFirst;
}

void UIHexEditorWnd::resetSelection(s64 pos)
{
   if (pos < 0)
      pos = 0;
   pos = pos / 2;
   selFirst = pos;
   selStart = pos;
   selEnd = pos;
}

void UIHexEditorWnd::setSelection(s64 pos)
{
   if (pos < 0)
      pos = 0;
   pos = pos / 2;
   if (pos >= (s64)endAddress + 1)
      pos = (s64)endAddress + 1;

   if (pos >= selFirst)
   {
      selEnd = pos;
      selStart = selFirst;
   }
   else
   {
      selStart = pos;
      selEnd = selFirst;
   }
}

u64 UIHexEditorWnd::getSelectionStart()
{
   return selStart;
}

u64 UIHexEditorWnd::getSelectionEnd()
{
   return selEnd;
}

bool UIHexEditorWnd::saveSelected(QString filename)
{
   FILE *fp=fopen(filename.toLatin1(), "wb");
   u32 size=(u32)(getSelectionEnd()-getSelectionStart())/2;

   if (fp == NULL)
      return false;

   u8 *buf = (unsigned char *)malloc(size);
   if (buf == NULL)
   {
      fclose(fp);
      return false;
   }

   for (u32 i = 0; i < size; i++)
      buf[i] = MappedMemoryReadByte((getSelectionStart() / 2)+i);

   if (fwrite((void *)buf, 1, size, fp) != size)
   {
      free(buf);
      fclose(fp);
      return false;
   }

   free(buf);
   fclose(fp);
   return true;
}
