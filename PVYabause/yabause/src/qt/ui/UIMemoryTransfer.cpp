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
#include "UIMemoryTransfer.h"
#include "UIHexInput.h"
#include "../CommonDialogs.h"

#include <QPushButton>

UIMemoryTransfer::UIMemoryTransfer( YabauseThread *mYabauseThread, QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

   this->mYabauseThread = mYabauseThread;

   leStartAddress->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leStartAddress));
   leEndAddress->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leEndAddress));

   leStartAddress->setText("06004000");
   leEndAddress->setText("06100000");

   cbPC->setCheckState(Qt::Checked);
   rbUpload->setChecked(true);

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

bool UIMemoryTransfer::areSettingsValid()
{
   if (leFile->text().length() == 0)
      return false;
   if (leStartAddress->text().length() == 0)
      return false;

   bool result;
   u32 startAddress = leStartAddress->text().toUInt(&result, 16);
   if (!result)
      return false;

   if (rbDownload->isChecked())
   {
      if (leEndAddress->text().length() == 0)
         return false;

      u32 endAddress = leEndAddress->text().toUInt(&result, 16);
      if (!result)
         return false;

      if (startAddress >= endAddress)
         return false;
   }

   return true;
}

void UIMemoryTransfer::on_leFile_textChanged( const QString & text )
{
   dbbButtons->button(QDialogButtonBox::Ok)->setEnabled(areSettingsValid());   
}

void UIMemoryTransfer::on_leStartAddress_textChanged( const QString & text )
{
   dbbButtons->button(QDialogButtonBox::Ok)->setEnabled(areSettingsValid());   
}

void UIMemoryTransfer::on_leEndAddress_textChanged( const QString & text )
{
   dbbButtons->button(QDialogButtonBox::Ok)->setEnabled(areSettingsValid());   
}

void UIMemoryTransfer::on_rbUpload_toggled(bool checked)
{
	leStartAddress->setEnabled(true);
   leEndAddress->setEnabled(checked != true);
   cbPC->setEnabled(checked == true);

   dbbButtons->button(QDialogButtonBox::Ok)->setEnabled(areSettingsValid());   
}

void UIMemoryTransfer::on_tbBrowse_clicked()
{
   if (rbDownload->isChecked())
   {
      const QString s = CommonDialogs::getSaveFileName( leFile->text(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
      if ( !s.isNull() )
         leFile->setText( s );
   }
   else
   {
      const QString s = CommonDialogs::getOpenFileName( leFile->text(), QtYabause::translate( "Choose a binary or program file" ), QtYabause::translate( "Binary Files (*.bin);;COFF Program Files (*.cof *.coff);;ELF Program Files (*.elf);;All Files (*)" ) );
      if ( !s.isNull() )
		{
         leFile->setText( s );
			if (s.endsWith(".cof", Qt::CaseInsensitive) ||
				 s.endsWith(".coff", Qt::CaseInsensitive) ||
				 s.endsWith(".elf", Qt::CaseInsensitive))
			{
				 cbPC->setCheckState(Qt::Checked);
			    cbPC->setEnabled(false);
				 leStartAddress->setEnabled(false);
			}
			else
			{
				cbPC->setEnabled(true);
				leStartAddress->setEnabled(true);
			}
		}
   }
}

void UIMemoryTransfer::accept()
{
   u32 startAddress = leStartAddress->text().toUInt(0, 16);
   u32 endAddress = leEndAddress->text().toUInt(0, 16);

   if (rbDownload->isChecked() && startAddress >= endAddress)
   {
      CommonDialogs::information(QtYabause::translate("Invalid Start/End Address Combination"), QtYabause::translate("Error"));
      return;
   }

	if (mYabauseThread)
      mYabauseThread->pauseEmulation( false, false );

   if (rbDownload->isChecked())
   {
      // Let's do a ram dump
      MappedMemorySave(leFile->text().toLatin1(), startAddress, endAddress - startAddress);
   }
   else
   {
      // upload to ram and possibly execute

      // Is this a program?
      if (cbPC->checkState() == Qt::Checked)
      {
         MappedMemoryLoadExec(leFile->text().toLatin1(), startAddress);
      }
      else
      {
         MappedMemoryLoad(leFile->text().toLatin1(), startAddress);
      }
   }

	QDialog::accept();
}
