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


UIControllerSetting::UIControllerSetting( PerInterface_struct* core, uint port, uint pad, uint perType, QWidget* parent )
	: QDialog( parent )
{
	Q_ASSERT( core );
	
	mCore = core;
	mPort = port;
	mPad = pad;
	mPerType = perType;
	mTimer = new QTimer( this );
	mTimer->setInterval( 25 );
	curTb = NULL;
	mPadKey = 0;
	mlInfos = NULL;
	scanFlags = PERSF_ALL;
	QtYabause::retranslateWidget( this );
}

UIControllerSetting::~UIControllerSetting()
{
}

void UIControllerSetting::setInfos(QLabel *lInfos)
{
   mlInfos = lInfos;
}

void UIControllerSetting::setScanFlags(u32 scanMask)
{
	switch (mPerType)
	{
		case PERPAD:
			scanFlags = PERSF_KEY | PERSF_BUTTON | PERSF_HAT;
			break;
		case PERWHEEL:
		case PERMISSIONSTICK:
		case PER3DPAD:
		case PERTWINSTICKS:
			scanFlags = PERSF_KEY | PERSF_BUTTON | PERSF_HAT | PERSF_AXIS;
			break;
		case PERGUN:
			scanFlags = PERSF_KEY | PERSF_BUTTON | PERSF_MOUSEMOVE;
			break;
		case PERKEYBOARD:
			scanFlags = PERSF_KEY;
			break;
		case PERMOUSE:
			scanFlags = PERSF_KEY | PERSF_BUTTON | PERSF_HAT | PERSF_MOUSEMOVE;
			break;
		default:
			scanFlags = PERSF_ALL;
			break;
	}

	scanFlags &= scanMask;
	setMouseTracking(scanFlags & PERSF_MOUSEMOVE ? true : false);
}

void UIControllerSetting::keyPressEvent( QKeyEvent* e )
{
	if ( mTimer->isActive() )
	{
		if ( e->key() != Qt::Key_Escape )
		{
			setPadKey( e->key() );
		}
		else
		{
			e->ignore();
			mButtons.key( mPadKey )->setChecked( false );
			mlInfos->clear();
			mTimer->stop();
			curTb->setAttribute(Qt::WA_TransparentForMouseEvents, false);
		}
	}
	else if ( e->key() == Qt::Key_Escape )
	{
		reject();
	}
	else
	{
		QWidget::keyPressEvent( e );
	}
}

void UIControllerSetting::mouseMoveEvent( QMouseEvent * e )
{
	if ( mTimer->isActive() )
	{
		if (scanFlags & PERSF_MOUSEMOVE)
			setPadKey((1 << 30));
	}
	else
		QWidget::mouseMoveEvent( e );
}

void UIControllerSetting::mousePressEvent( QMouseEvent * e )
{
	if ( mTimer->isActive() )
	{
		if (scanFlags & PERSF_BUTTON)
			setPadKey( (1 << 31) | e->button() );
	}
	else
		QWidget::mousePressEvent( e );
}

void UIControllerSetting::setPadKey( u32 key )
{
	Q_ASSERT( mlInfos );

	const QString settingsKey = QString( UIPortManager::mSettingsKey )
		.arg( mPort )
		.arg( mPad )
		.arg( mPerType )
		.arg( mPadKey );
	
	QtYabause::settings()->setValue( settingsKey, (quint32)key );
	mButtons.key( mPadKey )->setIcon( QIcon( ":/actions/icons/actions/button_ok.png" ) );
	mButtons.key( mPadKey )->setChecked( false );
	mlInfos->clear();
	mTimer->stop();
	if (curTb)
	   curTb->setAttribute(Qt::WA_TransparentForMouseEvents, false);
}

void UIControllerSetting::loadPadSettings()
{
	Settings* settings = QtYabause::settings();
	
	foreach ( const u8& name, mNames.keys() )
	{
		mPadKey = name;
		const QString settingsKey = QString( UIPortManager::mSettingsKey )
			.arg( mPort )
			.arg( mPad )
			.arg( mPerType )
			.arg( mPadKey );
		
		if ( settings->contains( settingsKey ) )
		{
			setPadKey( settings->value( settingsKey ).toUInt() );
		}
	}
}

bool UIControllerSetting::eventFilter( QObject* object, QEvent* event )
{
	if ( event->type() == QEvent::Paint )
	{
		QToolButton* tb = qobject_cast<QToolButton*>( object );
		
		if ( tb )
		{
			if ( tb->isChecked() )
			{
				QStylePainter sp( tb );
				QStyleOptionToolButton options;
				
				options.initFrom( tb );
				options.arrowType = Qt::NoArrow;
				options.features = QStyleOptionToolButton::None;
				options.icon = tb->icon();
				options.iconSize = tb->iconSize();
				options.state = QStyle::State_Enabled | QStyle::State_HasFocus | QStyle::State_On | QStyle::State_AutoRaise;
				
				sp.drawComplexControl( QStyle::CC_ToolButton, options );
				
				return true;
			}
		}
	}
	
	return false;
}

void UIControllerSetting::tbButton_clicked()
{
	QToolButton* tb = qobject_cast<QToolButton*>( sender() );
	
	if ( !mTimer->isActive() )
	{
		tb->setChecked( true );
		mPadKey = mButtons[ tb ];
	
		QString text1 = QtYabause::translate(QString("Awaiting input for"));
		QString text2 = QtYabause::translate(mNames[ mPadKey ]);
		QString text3 = QtYabause::translate(QString("Press Esc key to cancel"));

		mlInfos->setText( text1 + QString(": %1\n").arg(text2) + text3 );
		setScanFlags(mScanMasks[mPadKey]);
		mCore->Flush();
		curTb=tb;
		tb->setAttribute(Qt::WA_TransparentForMouseEvents);
		mTimer->start();
	}
	else
	{
		tb->setChecked( tb == mButtons.key( mPadKey ) );
	}
}

void UIControllerSetting::timer_timeout()
{
	u32 key = 0;
	key = mCore->Scan(scanFlags);
	
	if ( key != 0 )
	{
		setPadKey( key );
	}
}
