/*  Copyright 2005 Guillaume Duhamel
    Copyright 2005-2006 Theo Berkau
	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>

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
#include "UIAbout.h"
#include "../QtYabause.h"

UIAbout::UIAbout( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );
	if ( p && !p->isFullScreen() )
		setWindowFlags( Qt::Sheet );

	/* here we don't use QtYabause::retranslateWidget because it would search for the
	string with the current value of VERSION instead of the string with %1 in it... */
	lInformations->setText( QtYabause::translate( lInformations->text() ).arg( VERSION ));

	QtYabause::retranslateWidgetOnly( this );
}
