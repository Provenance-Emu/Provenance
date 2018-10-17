/*	Copyright 2013 Theo Berkau <cwx@cyberwarriorx.com>

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
#include "UIMouseSetting.h"
#include "UIPortManager.h"
#include "../Settings.h"

#include <QKeyEvent>
#include <QTimer>
#include <QStylePainter>
#include <QStyleOptionToolButton>

UIMouseSetting::UIMouseSetting( PerInterface_struct* core, uint port, uint pad, uint perType, QWidget* parent )
	: UIControllerSetting( core, port, pad, perType, parent )
{
   setupUi( this );
   setInfos(lInfos);
		
	mButtons[ tbStart ] = PERMOUSE_START;
	mButtons[ tbA ] = PERMOUSE_MIDDLE;
	mButtons[ tbB ] = PERMOUSE_LEFT;
	mButtons[ tbC ] = PERMOUSE_RIGHT;
	mButtons[ tbAxis ] = PERMOUSE_AXIS;
	
	mNames[ PERMOUSE_START ] = "Start";
	mNames[ PERMOUSE_MIDDLE ] = "Middle";
	mNames[ PERMOUSE_LEFT ] = "Left";
	mNames[ PERMOUSE_RIGHT ] = "Right";
	mNames[ PERMOUSE_AXIS ] = "Axis";

	mScanMasks[ PERMOUSE_START ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
	mScanMasks[ PERMOUSE_MIDDLE ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
	mScanMasks[ PERMOUSE_LEFT ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
	mScanMasks[ PERMOUSE_RIGHT ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
	mScanMasks[ PERMOUSE_AXIS ] = PERSF_MOUSEMOVE;

	loadPadSettings();
	
	foreach ( QToolButton* tb, findChildren<QToolButton*>() )
	{
		tb->installEventFilter( this );
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbButton_clicked() ) );
	}
	
	connect( mTimer, SIGNAL( timeout() ), this, SLOT( timer_timeout() ) );

	QtYabause::retranslateWidget( this );
}

UIMouseSetting::~UIMouseSetting()
{
}
