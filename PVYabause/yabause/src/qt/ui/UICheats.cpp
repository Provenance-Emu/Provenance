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
#include "UICheats.h"
#include "UICheatAR.h"
#include "UICheatRaw.h"
#include "../CommonDialogs.h"

UICheats::UICheats( QWidget* p )
	: QDialog( p )
{
	// set up dialog
	setupUi( this );
	if ( p && !p->isFullScreen() )
		setWindowFlags( Qt::Sheet );
	// cheat counts
	int cheatsCount;
	// get cheats
	mCheats = CheatGetList( &cheatsCount );
	// add know cheats to treewidget
	for ( int id = 0; id < cheatsCount; id++ )
		addCode( id );
	// set save button state
	pbSaveFile->setEnabled( cheatsCount );
	
	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UICheats::addCode( int id )
{
	// generate caption
	QString s;
	switch ( mCheats[id].type )
	{
		case CHEATTYPE_ENABLE:
			s = QtYabause::translate( "Enable Code : %1 %2" ).arg( (int)mCheats[id].addr, 8, 16, QChar( '0' ) ).arg( (int)mCheats[id].val, 8, 16, QChar( '0' ) );
			break;
		case CHEATTYPE_BYTEWRITE:
			s = QtYabause::translate( "Byte Write : %1 %2" ).arg( (int)mCheats[id].addr, 8, 16, QChar( '0' ) ).arg( (int)mCheats[id].val, 2, 16, QChar( '0' ) );
			break;
		case CHEATTYPE_WORDWRITE:
			s = QtYabause::translate( "Word Write : %1 %2" ).arg( (int)mCheats[id].addr, 8, 16, QChar( '0' ) ).arg( (int)mCheats[id].val, 4, 16, QChar( '0' ) );
			break;
		case CHEATTYPE_LONGWRITE:
			s = QtYabause::translate( "Long Write : %1 %2" ).arg( (int)mCheats[id].addr, 8, 16, QChar( '0' ) ).arg( (int)mCheats[id].val, 8, 16, QChar( '0' ) );
			break;
		default:
			break;
	}
	// update item
	QTreeWidgetItem* it = new QTreeWidgetItem( twCheats );
	it->setText( 0, s );
	it->setText( 1, mCheats[id].desc );
	it->setText( 2, mCheats[id].enable ? QtYabause::translate( "Enabled" ) : QtYabause::translate( "Disabled" ) );
	// enable buttons
	pbClear->setEnabled( true );
	pbSaveFile->setEnabled( true );
}

void UICheats::addARCode( const QString& c, const QString& d )
{
	// need check in list if already is code
	// add code
	if ( CheatAddARCode( c.toLatin1().constData() ) != 0 )
	{
		CommonDialogs::information( QtYabause::translate( "Unable to add code" ) );
		return;
	}
	// change the description
	int cheatsCount;
	mCheats = CheatGetList( &cheatsCount );
	if ( CheatChangeDescriptionByIndex( cheatsCount -1, d.toLatin1().data() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Unable to change description" ) );
	// add code in treewidget
	addCode( cheatsCount -1 );
}

void UICheats::addRawCode( int t, const QString& a, const QString& v, const QString& d )
{
	// need check in list if already is code
	bool b;
	quint32 u;
	// check address
	u = a.toUInt( &b, 16 );
	if ( !b )
	{
		CommonDialogs::information( QtYabause::translate( "Invalid Address" ) );
		return;
	}
	// check value
	u = v.toUInt( &b, 16 );
	if ( !b )
	{
		CommonDialogs::information( QtYabause::translate( "Invalid Value" ) );
		return;
	}
	// add value
	if ( CheatAddCode( t, a.toUInt(NULL, 16), v.toUInt() ) != 0 )
	{
		CommonDialogs::information( QtYabause::translate( "Unable to add code" ) );
		return;
	}
	// get cheats and cheats count
	int cheatsCount;
	mCheats = CheatGetList( &cheatsCount );
	// change description
	if ( CheatChangeDescriptionByIndex( cheatsCount -1, d.toLatin1().data() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Unable to change description" ) );
	// add code in treewidget
	addCode( cheatsCount -1 );
}

void UICheats::on_twCheats_itemSelectionChanged()
{ pbDelete->setEnabled( twCheats->selectedItems().count() ); }

void UICheats::on_twCheats_itemDoubleClicked( QTreeWidgetItem* it, int )
{
	if ( it )
	{
		// get id of item
		int id = twCheats->indexOfTopLevelItem( it );
		// if ok
		if ( id != -1 )
		{
			// disable cheat
			if ( mCheats[id].enable )
				CheatDisableCode( id );
			// enable cheat
			else
				CheatEnableCode( id );
			// update treewidget item
			it->setText( 2, mCheats[id].enable ? QtYabause::translate( "Enabled" ) : QtYabause::translate( "Disabled" ) );
		}
	}
}

void UICheats::on_pbDelete_clicked()
{
	// get current selected item
	if ( QTreeWidgetItem* it = twCheats->selectedItems().value( 0 ) )
	{
		// get item id
		int id = twCheats->indexOfTopLevelItem( it );
		// remove cheat
		if ( CheatRemoveCodeByIndex( id ) != 0 )
		{
			CommonDialogs::information( QtYabause::translate( "Unable to remove code" ) );
			return;
		}
		// delete item
		delete it;
		// disable buttons
		pbClear->setEnabled( twCheats->topLevelItemCount() );
	}
}

void UICheats::on_pbClear_clicked()
{
	// clear cheats
	CheatClearCodes();
	// clear treewidget items
	twCheats->clear();
	// disable buttons
	pbDelete->setEnabled( false );
	pbClear->setEnabled( false );
}

void UICheats::on_pbAR_clicked()
{
	// add AR code if dialog exec
	UICheatAR d( this );
	if ( d.exec() )
		addARCode( d.leCode->text(), d.teDescription->toPlainText() );
}

void UICheats::on_pbRaw_clicked()
{
	// add RAW code if dialog exec
	UICheatRaw d( this );
	if ( d.exec() && d.type() != -1 )
		addRawCode( d.type(), d.leAddress->text(), d.leValue->text(), d.teDescription->toPlainText() );
}

void UICheats::on_pbSaveFile_clicked()
{
	const QString s = CommonDialogs::getSaveFileName( ".", QtYabause::translate( "Choose a cheat file to save to" ), QtYabause::translate( "Yabause Cheat Files (*.yct);;All Files (*)" ) );
	if ( !s.isEmpty() )
		if ( CheatSave( s.toLatin1().constData() ) != 0 )
			CommonDialogs::information( QtYabause::translate( "Unable to open file for loading" ) );
}

void UICheats::on_pbLoadFile_clicked()
{
	const QString s = CommonDialogs::getOpenFileName( ".", QtYabause::translate( "Choose a cheat file to open" ), QtYabause::translate( "Yabause Cheat Files (*.yct);;All Files (*)" ) );
	if ( !s.isEmpty() )
	{
		if ( CheatLoad( s.toLatin1().constData() ) == 0 )
		{
			// clear tree
			twCheats->clear();
			// get cheats and cheats count
			int cheatsCount;
			mCheats = CheatGetList( &cheatsCount );
			// add cheats
			for ( int i = 0; i < cheatsCount; i++ )
				addCode( i );
		}
		else
			CommonDialogs::information( QtYabause::translate( "Unable to open file for saving" ) );
	}
}
