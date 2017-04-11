/*	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>
	Copyright 2013 Theo Berkau <cwx@cyberwarriorx.com>

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
#include "UIPadSetting.h"
#include "UIPortManager.h"
#include "../Settings.h"

#include <QKeyEvent>
#include <QTimer>
#include <QStylePainter>
#include <QStyleOptionToolButton>

// Make a parent class for all controller setting classes


UIPadSetting::UIPadSetting( PerInterface_struct* core, uint port, uint pad, uint perType, QWidget* parent )
	: UIControllerSetting( core, port, pad, perType, parent )
{
   setupUi( this );
   setInfos(lInfos);
		
	mButtons[ tbUp ] = PERPAD_UP;
	mButtons[ tbRight ] = PERPAD_RIGHT;
	mButtons[ tbDown ] = PERPAD_DOWN;
	mButtons[ tbLeft ] = PERPAD_LEFT;
	mButtons[ tbRightTrigger ] = PERPAD_RIGHT_TRIGGER;
	mButtons[ tbLeftTrigger ] = PERPAD_LEFT_TRIGGER;
	mButtons[ tbStart ] = PERPAD_START;
	mButtons[ tbA ] = PERPAD_A;
	mButtons[ tbB ] = PERPAD_B;
	mButtons[ tbC ] = PERPAD_C;
	mButtons[ tbX ] = PERPAD_X;
	mButtons[ tbY ] = PERPAD_Y;
	mButtons[ tbZ ] = PERPAD_Z;
	
	mNames[ PERPAD_UP ] = QtYabause::translate( "Up" );
	mNames[ PERPAD_RIGHT ] = QtYabause::translate( "Right" );
	mNames[ PERPAD_DOWN ] = QtYabause::translate( "Down" );
	mNames[ PERPAD_LEFT ] = QtYabause::translate( "Left" );
	mNames[ PERPAD_RIGHT_TRIGGER ] = QtYabause::translate( "Right trigger" );;
	mNames[ PERPAD_LEFT_TRIGGER ] = QtYabause::translate( "Left trigger" );;
	mNames[ PERPAD_START ] = "Start";
	mNames[ PERPAD_A ] = "A";
	mNames[ PERPAD_B ] = "B";
	mNames[ PERPAD_C ] = "C";
	mNames[ PERPAD_X ] = "X";
	mNames[ PERPAD_Y ] = "Y";
	mNames[ PERPAD_Z ] = "Z";
	
   mScanMasks[ PERPAD_UP ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_RIGHT ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_DOWN ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_LEFT ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_RIGHT_TRIGGER ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_LEFT_TRIGGER ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_START ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_A ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_B ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_C ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_X ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_Y ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
   mScanMasks[ PERPAD_Z ] = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;

	loadPadSettings();
	
	foreach ( QToolButton* tb, findChildren<QToolButton*>() )
	{
		tb->installEventFilter( this );
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbButton_clicked() ) );
	}
	
	connect( mTimer, SIGNAL( timeout() ), this, SLOT( timer_timeout() ) );

	QtYabause::retranslateWidget( this );
}

UIPadSetting::~UIPadSetting()
{
}
