/*	Copyright 2012-2013 Theo Berkau <cwx@cyberwarriorx.com>

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

#include "UIMemoryEditor.h"
#include "UIHexInput.h"
#include "UIMemorySearch.h"
#include "Settings.h"
#include "../CommonDialogs.h"

MemorySearch::MemorySearch(UIMemorySearch *memorySearch, QObject *parent)
   : QObject(parent)
{
   bool ok;

   searchType = memorySearch->cbType->itemData(memorySearch->cbType->currentIndex()).toInt();
   searchString = memorySearch->leValue->text();
   startAddress = memorySearch->leStartAddress->text().toUInt(&ok, 16);
   endAddress = memorySearch->leEndAddress->text().toUInt(&ok, 16);
   searchSize = 0x10000;

   timer = new QTimer(this);
   connect(timer, SIGNAL(timeout()), this, SLOT(process()));

   curAddress=startAddress;
}

MemorySearch::~MemorySearch()
{
   delete timer;
}

void MemorySearch::setStartAddress( u32 address )
{
   curAddress = startAddress = address;
}

void MemorySearch::process() 
{
   result_struct *results;
   u32 numResults=1;
   int searchEnd;

   if ((endAddress - curAddress) > searchSize)
      searchEnd = curAddress+searchSize;
   else
      searchEnd = endAddress;

   results = MappedMemorySearch(curAddress, searchEnd,
      searchType | SEARCHEXACT,
      searchString.toLatin1().constData(),
      NULL, &numResults);
   if (results && numResults)
   {
      timer->stop();

      // We're done
      emit searchResult(true, false, results[0].addr);
      return;
   }

   if (results)
      free(results);

   curAddress += (searchEnd - curAddress);
   if (curAddress >= endAddress)
   {
      timer->stop();
      emit searchResult(false, false, 0);
      return;
   }

   steps++;
   emit setBarValue(steps);
}

void MemorySearch::start()
{
   timer->start(0);
   steps=0;
   emit setBarRange(startAddress / searchSize, (endAddress / searchSize) + 1);
}

void MemorySearch::cancel()
{
   timer->stop();
   emit searchResult(false, true, 0);
}

UIMemoryEditor::UIMemoryEditor( YabauseThread *mYabauseThread, QWidget* p )
	: QDialog( p )
{
	// set up dialog
	setupUi( this );
	if ( p && !p->isFullScreen() )
		setWindowFlags( Qt::WindowMaximizeButtonHint | Qt::Sheet );


   gotoAddress = 0;
   searchType = SEARCHHEX;
   searchString = QString("");
   searchStartAddress = 0;
   searchEndAddress = 0;
   if (mYabauseThread->init() < 0)
   {
      saMemoryEditor->setEnabled(false);
      pbGotoAddress->setEnabled(false);
      pbSaveSelected->setEnabled(false);
      pbSearchMemory->setEnabled(false);
   }
   else
      saMemoryEditor->setFocus();
   
	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIMemoryEditor::on_pbGotoAddress_clicked()
{
   UIHexInput hex(gotoAddress, 4, this);

   if (hex.exec() == QDialog::Accepted)
   {
      gotoAddress = hex.getValue();
      saMemoryEditor->goToAddress(gotoAddress);
      saMemoryEditor->setFocus();
   }
}

void UIMemoryEditor::on_pbSaveSelected_clicked()
{
   QString fn = CommonDialogs::getSaveFileName( getDataDirPath(), QtYabause::translate( "Choose a location for binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
   if (!fn.isEmpty())
      saMemoryEditor->saveSelected(fn);
}

void UIMemoryEditor::on_pbSearchMemory_clicked()
{
   UIMemorySearch memorySearch( this );
   
   if (searchStartAddress == 0 && searchEndAddress == 0)
   {
      UIHexEditorWnd *hexEditorWnd=(UIHexEditorWnd *)saMemoryEditor->currentWidget();
      searchStartAddress = hexEditorWnd->getStartAddress();
      searchEndAddress = hexEditorWnd->getEndAddress();
   }

   memorySearch.setParameters(searchType, searchString, searchStartAddress, searchEndAddress);
   if (memorySearch.exec() == QDialog::Accepted)
   {
      MemorySearch search( &memorySearch );
      QProgressDialog progress;
      
      progress.setLabelText("Searching memory...");

      connect(&search, SIGNAL(searchResult(bool, bool, u32)), this, SLOT(searchResult(bool, bool, u32)));
      connect(this, SIGNAL(killProgressDialog()), &progress, SLOT(accept()));
      connect(&progress, SIGNAL(canceled()), &search, SLOT(cancel()));
      connect(&search, SIGNAL(setBarValue(int)), &progress, SLOT(setValue(int)));
      connect(&search, SIGNAL(setBarRange(int, int)), &progress, SLOT(setRange(int, int)));

      search.start();
      progress.exec();
   }
}

void UIMemoryEditor::searchResult(bool found, bool cancel, u32 address)
{
   if (!cancel)
   {
      emit killProgressDialog();
      if (found)
         saMemoryEditor->goToAddress(address);
      else
      {
         if (searchStartAddress != saMemoryEditor->getStartAddress())
         {
            if (CommonDialogs::question("Finished searching up to end of memory, continue from the beginning?"))
            {
               //search->setStartAddress(saMemoryEditor->getStartAddress());
               //search->start();
            }
         }
         else
            CommonDialogs::information( "No matches found." );
      }
   }
}
