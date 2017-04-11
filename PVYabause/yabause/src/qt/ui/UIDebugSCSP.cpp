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
#include "UIDebugSCSP.h"
#include "CommonDialogs.h"

#include <QImageWriter>
#include <QGraphicsPixmapItem>

UIDebugSCSP::UIDebugSCSP( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

   sbSlotNumber->setMinimum(0);
   sbSlotNumber->setMaximum(31);
   sbSlotNumber->setValue(31);
   sbSlotNumber->setValue(0);

   // Setup Common Control registers
   if (HighWram)
   {
      char tempstr[2048];
      ScspCommonControlRegisterDebugStats(tempstr);
      pteCommonControlRegisters->appendPlainText(tempstr);
      pteCommonControlRegisters->moveCursor(QTextCursor::Start);
   }

   // Disable DSP Register display
   gbDSPControlRegisters->setVisible( false );

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIDebugSCSP::on_sbSlotNumber_valueChanged ( int i )
{
   // Update Sound Slot Info
   char tempstr[2048];
   if (HighWram)
   {
      ScspSlotDebugStats(i, tempstr);
      pteSlotInfo->clear();
      pteSlotInfo->appendPlainText(tempstr);
      pteSlotInfo->moveCursor(QTextCursor::Start);
      pbSaveAsWav->setEnabled(true);
      pbSaveSlotRegisters->setEnabled(true);
   }
   else
   {
      pbSaveAsWav->setEnabled(false);
      pbSaveSlotRegisters->setEnabled(false);
   }
}

void UIDebugSCSP::on_pbSaveAsWav_clicked ()
{
	// request a file to save to to user
   QString text;
   
   text.sprintf("channel%02d.wav", sbSlotNumber->value());
	const QString s = CommonDialogs::getSaveFileName(text, QtYabause::translate( "Choose a location for your wav file" ), QtYabause::translate( "WAV Files (*.wav)" ) );
	
	// write image if ok
	if ( !s.isEmpty() )
		if (ScspSlotDebugAudioSaveWav(sbSlotNumber->value(), s.toLatin1()) != 0)
			CommonDialogs::information( QtYabause::translate( "An error occured while writing file." ) );                  
}

void UIDebugSCSP::on_pbSaveSlotRegisters_clicked ()
{
	const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for your binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
	if ( !s.isEmpty() )
      if (ScspSlotDebugSaveRegisters(sbSlotNumber->value(), s.toLatin1()) != 0)
			CommonDialogs::information( QtYabause::translate( "An error occured while writing file." ) );
}
