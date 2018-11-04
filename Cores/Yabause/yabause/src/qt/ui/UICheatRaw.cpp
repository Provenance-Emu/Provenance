/*	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>

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
#include "UICheatRaw.h"
#include "UIHexInput.h"
#include "../QtYabause.h"

#include <QButtonGroup>

UICheatRaw::UICheatRaw( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

	// fill types
	mButtonGroup = new QButtonGroup( this );
	mButtonGroup->addButton( rbEnable, CHEATTYPE_ENABLE );
	mButtonGroup->addButton( rbByte, CHEATTYPE_BYTEWRITE );
	mButtonGroup->addButton( rbWord, CHEATTYPE_WORDWRITE );
	mButtonGroup->addButton( rbLong, CHEATTYPE_LONGWRITE );

	leAddress->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leAddress));
	leValue->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leValue));

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}
