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
#include "UIHexInput.h"

UIHexInput::UIHexInput( u32 value, int size, QWidget* p )
	: QDialog( p )
{
   char format[5];

	// setup dialog
	setupUi( this );

   // Setup Text control
   QString text;
   sprintf(format, "%%0%dX", size * 2);
   text.sprintf(format, value);
  
	leValue->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF >> (4-size * 8) , leValue));
   leValue->setText(text);

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

u32 UIHexInput::getValue()
{
   return value;
}

void UIHexInput::accept()
{
   value = leValue->text().toUInt(0, 16);
	QDialog::accept();
}
