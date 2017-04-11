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
#include "UIWaitInput.h"

#include <QTimer>
#include <QKeyEvent>

UIWaitInput::UIWaitInput( PerInterface_struct* c, const QString& pk, QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

	// set focus
	setFocusPolicy( Qt::StrongFocus );
	setFocus();

	// get core
	mCore = c;
	Q_ASSERT( mCore );

	// remember key to scan
	mPadKey = pk;

	// init core
	if ( mCore->Init() != 0 )
		qWarning( "UIWaitInput: Can't Init Core" );
	
	if ( mCore->canScan == 1 )
	{
		// create timer for input scan
		QTimer* mTimerInputScan = new QTimer( this );
		mTimerInputScan->setInterval( 25 );
		
		// connect
		connect( mTimerInputScan, SIGNAL( timeout() ), this, SLOT( inputScan_timeout() ) );
		
		// start input scan
		mTimerInputScan->start();
	}
	
	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIWaitInput::keyPressEvent( QKeyEvent* e )
{
	if ( e->key() != Qt::Key_Escape )
	{
		mKeyString = QString::number( e->key() );
		QDialog::accept();
	}
	QWidget::keyPressEvent( e );
}

void UIWaitInput::inputScan_timeout()
{
	u32 k = 0;
	mCore->Flush();
	k = mCore->Scan(PERSF_KEY | PERSF_BUTTON | PERSF_HAT);
	if ( k != 0 )
	{
		sender()->deleteLater();
		mKeyString = QString::number( k );
		QDialog::accept();
	}
}
