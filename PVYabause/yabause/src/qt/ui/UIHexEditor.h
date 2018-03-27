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
#ifndef UIHEXEDITOR_H
#define UIHEXEDITOR_H

#include <QPen>
#include <QScrollArea>
#include <QTimer>
#include <QTabWidget>
#include <QVBoxLayout>
#include "../QtYabause.h"

class UIHexEditorWnd : public QAbstractScrollArea
{
	Q_OBJECT
public:
	UIHexEditorWnd( QWidget* parent = 0 );

   void setAddrAreaColor(const QColor &color);
   void setStartAddress(u32 address);
   u32 getStartAddress();
   void setEndAddress(u32 address);
   u32 getEndAddress();
   u32 getAddress();
   void goToAddress(u32 address, bool setCursor=true);
   virtual void setFont(const QFont &font);
   bool saveSelected(QString filename);
   bool saveTab(QString filename);
private:
   void keyPressCursor(QKeyEvent *event);
   void keyPressSelect(QKeyEvent *event);
   void keyPressEdit(QKeyEvent *event, u64 posBa);
   void adjustSettings();
   void clear(u32 index, int len);
   void overwrite(s64 index, char ch);
   void overwrite(u32 addr, u8 data);
   s64 cursorPos(QPoint pos, bool toggleTextEdit=true);
   s64 cursorPos();
   void resetSelection();
   void resetSelection(s64 pos);
   void setSelection(s64 pos);
   u64 getSelectionStart();
   u64 getSelectionEnd();
   void drawHeaderArea(QPainter *painter, int left, int top, int right);
   void drawAddressArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr);
   void drawHexArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr);
   void drawTextArea(QPainter *painter, int firstLineIdx, u32 lastLineIdx, int yPosStart, u32 addr);

   QTimer cursorTimer;
   QTimer autoScrollTimer;

   int hexCharsInLine;
   int gapSizeAddrHex;
   int gapSizeHexText;
   int bytesPerGroup;
   int nibblesPerGroup;
   int bytesPerLine;
   QColor addrAreaColor;
   QBrush highLighted, selected;
   QPen textColor, textColorAlt, colHighlighted, colSelected;

   int fontAscent, fontWidth, fontHeight;

   int headerHeight;
   int yPosEdit;
   int posAddr;
   int posHex;
   int posText;

   int hoverX, hoverY;
   int cursorX, cursorY;
   int cursorTextX, cursorTextY;
   bool blinkCursor;
   s64 cursorAddr;
   bool textEdit;

   QPoint autoScrollDragPos;
   int autoScrollDir;
   s64 selStart, selEnd, selFirst;

   u32 startAddress;
   u32 endAddress;
protected:
   void keyPressEvent(QKeyEvent *event);
   void mouseMoveEvent(QMouseEvent * event);
   void mousePressEvent(QMouseEvent * event);
   void mouseReleaseEvent(QMouseEvent * event);
   void paintEvent(QPaintEvent *event);
   void resizeEvent(QResizeEvent * event);
   void setCursorPos(s64 position);
   void setHoverPos(s64 position);
private slots:
   void updateCursor();
   void autoScroll();
   void sliderUpdate(int value);
   virtual bool focusNextPrevChild(bool next);
   bool saveMemory(QString filename, u32 startAddress, u32 endAddress);
};

class UIHexEditor : public QTabWidget
{
   Q_OBJECT
public:
   UIHexEditor( QWidget* parent = 0 );

   void goToAddress(u32 address, bool setCursor=true);
   u32 getStartAddress();
   u32 getEndAddress();
   bool saveSelected(QString filename);
   bool saveTab(QString filename);
private:
   ;
};

#endif // UIHEXEDITOR_H
