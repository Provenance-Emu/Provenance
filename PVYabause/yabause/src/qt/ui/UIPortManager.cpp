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
#include "UIPortManager.h"
#include "UIPadSetting.h"
#include "UI3DControlPadSetting.h"
#include "UIGunSetting.h"
#include "UIMouseSetting.h"
#include "../CommonDialogs.h"
#include "../Settings.h"

#include <QDebug>

/*
key = (peripheralid << 16) | buttonid;
peripheralid = (key >> 16);
buttonid = key & 0xFFFF;
*/

const QString UIPortManager::mSettingsKey = "Input/Port/%1/Id/%2/Controller/%3/Key/%4";
const QString UIPortManager::mSettingsType = "Input/Port/%1/Id/%2/Type";

UIPortManager::UIPortManager( QWidget* parent )
	: QGroupBox( parent )
{
	mPort = -1;
	mCore = 0;
	setupUi( this );

	foreach ( QComboBox* cb, findChildren<QComboBox*>( QRegExp( "cbTypeController*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		cb->addItem( QtYabause::translate( "None" ), 0 );
		cb->addItem( QtYabause::translate( "Pad" ), PERPAD );
      //cb->addItem( QtYabause::translate( "Wheel" ), PERWHEEL );
      cb->addItem( QtYabause::translate( "3D Control Pad" ), PER3DPAD );
      cb->addItem( QtYabause::translate( "Gun" ), PERGUN );
      //cb->addItem( QtYabause::translate( "Keyboard" ), PERKEYBOARD );
		cb->addItem( QtYabause::translate( "Mouse" ), PERMOUSE );

		connect( cb, SIGNAL( currentIndexChanged( int ) ), this, SLOT( cbTypeController_currentIndexChanged( int ) ) );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbSetJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbSetJoystick_clicked() ) );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbClearJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbClearJoystick_clicked() ) );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbRemoveJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbRemoveJoystick_clicked() ) );
	}
}

UIPortManager::~UIPortManager()
{
}

void UIPortManager::setPort( uint port )
{
	mPort = port;
}

void UIPortManager::setCore( PerInterface_struct* core )
{
	Q_ASSERT( core );
	mCore = core;
}

void UIPortManager::loadSettings()
{
	// reset gui
	foreach ( QComboBox* cb, findChildren<QComboBox*>( QRegExp( "cbTypeController*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		bool blocked = cb->blockSignals( true );
		cb->setCurrentIndex( 0 );
		cb->blockSignals( blocked );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbSetJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		tb->setEnabled( false );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbClearJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		tb->setEnabled( false );
	}

	foreach ( QToolButton* tb, findChildren<QToolButton*>( QRegExp( "tbRemoveJoystick*", Qt::CaseInsensitive, QRegExp::Wildcard ) ) )
	{
		tb->setEnabled( false );
	}

	// load settings
	Settings* settings = QtYabause::settings();

	settings->beginGroup( QString( "Input/Port/%1/Id" ).arg( mPort ) );
	QStringList ids = settings->childGroups();
	settings->endGroup();

	if (ids.isEmpty() && mPort == 1)
	{
		QComboBox* cb = findChild<QComboBox*>( QString( "cbTypeController1" ) );
		cb->setCurrentIndex(1);
	}

	ids.sort();
	foreach ( const QString& id, ids )
	{
		uint type = settings->value( QString( mSettingsType ).arg( mPort ).arg( id ) ).toUInt();
		QComboBox* cb = findChild<QComboBox*>( QString( "cbTypeController%1" ).arg( id ) );
		cb->setCurrentIndex( cb->findData( type ) );
	}
}

void UIPortManager::cbTypeController_currentIndexChanged( int id )
{
	QObject* frame = sender()->parent();
	QList<QToolButton*> buttons = frame->findChildren<QToolButton*>();
	uint type = qobject_cast<QComboBox*>( sender() )->itemData( id ).toInt();
	uint controllerId = frame->objectName().remove( "fController" ).toUInt();

	switch ( type )
	{
		case PERPAD:
		case PERWHEEL:
		case PER3DPAD:
		case PERMOUSE:
			buttons.at( 0 )->setEnabled( true );
			buttons.at( 1 )->setEnabled( true );
			buttons.at( 2 )->setEnabled( true );
			break;
		case PERGUN:
			buttons.at( 0 )->setEnabled( true );
			buttons.at( 1 )->setEnabled( true );
			buttons.at( 2 )->setEnabled( true );
			break;
		case PERKEYBOARD:
			buttons.at( 0 )->setEnabled( false );
			buttons.at( 1 )->setEnabled( false );
			buttons.at( 2 )->setEnabled( true );
			break;
		default:
			buttons.at( 0 )->setEnabled( false );
			buttons.at( 1 )->setEnabled( false );
			buttons.at( 2 )->setEnabled( false );
			break;
	}

	Settings* settings = QtYabause::settings();
	settings->setValue( QString( mSettingsType ).arg( mPort ).arg( controllerId ), type );
}

void UIPortManager::tbSetJoystick_clicked()
{
	uint controllerId = sender()->objectName().remove( "tbSetJoystick" ).toUInt();
	QComboBox* cb = findChild<QComboBox*>( QString( "cbTypeController%1" ).arg( controllerId ) );
	uint type = cb->itemData(cb->currentIndex()).toUInt();
	switch (type)
	{
		case PERPAD:
		{
			QMap<uint, PerPad_struct*>& padsbits = *QtYabause::portPadsBits( mPort );

			PerPad_struct* padBits = padsbits[ controllerId ];

			if ( !padBits )
			{
				padBits = PerPadAdd( mPort == 1 ? &PORTDATA1 : &PORTDATA2 );

				if ( !padBits )
				{
					CommonDialogs::warning( QtYabause::translate( "Can't plug in the new controller, cancelling." ) );
					return;
				}

				padsbits[ controllerId ] = padBits;
			}

			UIPadSetting ups( mCore, mPort, controllerId, type, this );
			ups.exec();
			break;
		}
		case PER3DPAD:
		{
			QMap<uint, PerAnalog_struct*>& analogbits = *QtYabause::portAnalogBits( mPort );

			PerAnalog_struct* analogBits = analogbits[ controllerId ];

			if ( !analogBits )
			{
				analogBits = Per3DPadAdd( mPort == 1 ? &PORTDATA1 : &PORTDATA2 );

				if ( !analogBits )
				{
					CommonDialogs::warning( QtYabause::translate( "Can't plug in the new controller, cancelling." ) );
					return;
				}

				analogbits[ controllerId ] = analogBits;
			}

			UI3DControlPadSetting uas( mCore, mPort, controllerId, type, this );
			uas.exec();
			break;
		}
		case PERGUN:
		{
			QMap<uint, PerGun_struct*>& gunbits = *QtYabause::portGunBits( mPort );

			PerGun_struct* gunBits = gunbits[ controllerId ];

			if ( !gunBits )
			{
				gunBits = PerGunAdd( mPort == 1 ? &PORTDATA1 : &PORTDATA2 );

				if ( !gunBits )
				{
					CommonDialogs::warning( QtYabause::translate( "Can't plug in the new controller, cancelling." ) );
					return;
				}

				gunbits[ controllerId ] = gunBits;
			}

			UIGunSetting ums( mCore, mPort, controllerId, type, this );
			ums.exec();
			break;
		}
		case PERMOUSE:
		{
			QMap<uint, PerMouse_struct*>& mousebits = *QtYabause::portMouseBits( mPort );

			PerMouse_struct* mouseBits = mousebits[ controllerId ];

			if ( !mouseBits )
			{
				mouseBits = PerMouseAdd( mPort == 1 ? &PORTDATA1 : &PORTDATA2 );

				if ( !mouseBits )
				{
					CommonDialogs::warning( QtYabause::translate( "Can't plug in the new controller, cancelling." ) );
					return;
				}

				mousebits[ controllerId ] = mouseBits;
			}

			UIMouseSetting ums( mCore, mPort, controllerId, type, this );
			ums.exec();
			break;
		}
		default: break;
	}
}

void UIPortManager::tbClearJoystick_clicked()
{
	uint controllerId = sender()->objectName().remove( "tbClearJoystick" ).toUInt();
	const QString group = QString( "Input/Port/%1/Id/%2" ).arg( mPort ).arg( controllerId );
	Settings* settings = QtYabause::settings();
	uint type = settings->value( QString( mSettingsType ).arg( mPort ).arg( controllerId ), 0 ).toUInt();

	settings->remove( group );

	if ( type > 0 )
	{
		settings->setValue( QString( mSettingsType ).arg( mPort ).arg( controllerId ), type );
	}
}

void UIPortManager::tbRemoveJoystick_clicked()
{
	uint controllerId = sender()->objectName().remove( "tbRemoveJoystick" ).toUInt();
	QComboBox* cb = findChild<QComboBox*>( QString( "cbTypeController%1" ).arg( controllerId ) );
	cb->setCurrentIndex(0);
}
