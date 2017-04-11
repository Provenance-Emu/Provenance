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

#include "UIMemorySearch.h"
#include "UIHexInput.h"
#include "../CommonDialogs.h"
#include <QPushButton>

UIMemorySearch::UIMemorySearch( QWidget* p )
	: QDialog( p )
{
	// set up dialog
	setupUi( this );
	if ( p && !p->isFullScreen() )
		setWindowFlags( Qt::Sheet );

   QStringList typeList = (QStringList() << 
                           QtYabause::translate("Hex value(s)") << 
                           QtYabause::translate("Text") << 
                           QtYabause::translate("8-bit Relative value(s)") << 
                           QtYabause::translate("16-bit Relative value(s)") << 
                           QtYabause::translate("Unsigned 8-bit value") << 
                           QtYabause::translate("Signed 8-bit value") <<
                           QtYabause::translate("Unsigned 16-bit value") <<
                           QtYabause::translate("Signed 16-bit value") <<
                           QtYabause::translate("Unsigned 32-bit value") <<
                           QtYabause::translate("Signed 32-bit value"));
   QList<int> flagList;
   flagList << SEARCHHEX << SEARCHSTRING << SEARCHREL8BIT << SEARCHREL16BIT << 
               (SEARCHUNSIGNED|SEARCHBYTE) << (SEARCHSIGNED|SEARCHBYTE) <<
               (SEARCHUNSIGNED|SEARCHWORD) << (SEARCHSIGNED|SEARCHWORD) <<
               (SEARCHUNSIGNED|SEARCHLONG) << (SEARCHSIGNED|SEARCHLONG);

   cbType->addItems(typeList);

   for (int i = 0; i < flagList.count(); i++)
      cbType->setItemData(i, flagList[i]);

   adjustSearchValueQValidator();

   leStartAddress->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leStartAddress));
   leEndAddress->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leEndAddress));

	(dbbButtons->button(QDialogButtonBox::Ok))->setEnabled(!(leValue->text()).isEmpty());

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIMemorySearch::setParameters(int type, QString string, u32 startAddress, u32 endAddress)
{
   int index = cbType->findData(type);
   if (index != -1)
      cbType->setCurrentIndex(index);
   leValue->setText(string);
   leStartAddress->setText(QString("%1").arg(startAddress, 8, 16, QChar('0')).toUpper());
   leEndAddress->setText(QString("%1").arg(endAddress, 8, 16, QChar('0')).toUpper());
}

void UIMemorySearch::adjustSearchValueQValidator()
{
   // Figure out range
   int min, max;

   min = 0;

   int data = cbType->itemData(cbType->currentIndex()).toInt();

   switch (data)
   {
      case SEARCHHEX:
         leValue->setValidator(new HexValidator(0x00000000, 0xFFFFFFFF, leValue));
         leValue->setText("");
         break;
      case SEARCHSTRING:
         leValue->setValidator(NULL);
         leValue->setText("");
         break;
      case SEARCHREL8BIT:
         leValue->setValidator(new QRegExpValidator(QRegExp("([0-9a-fA-F]{1,2})(,\\s*[0-9a-fA-F]{1,2})*"), leValue));
         leValue->setText("");
         break;
      case SEARCHREL16BIT:
         leValue->setValidator(new QRegExpValidator(QRegExp("([0-9a-fA-F]{1,4})(,\\s*[0-9a-fA-F]{1,4})*"), leValue));
         leValue->setText("");
         break;
      default: 
      {
         bool isSigned = data & SEARCHSIGNED;
         data &= ~SEARCHSIGNED;

         if (data == SEARCHBYTE)
            max = 0xFF;
         else if (data == SEARCHWORD)
            max = 0xFFFF;
         else if (data == SEARCHLONG)
            max = 0xFFFFFFFF;

         if (isSigned)
         {
            min = -(max >> 1) - 1;
            max >>= 1;
         }

         if (data == SEARCHLONG)
         {
            if (isSigned)
               leValue->setValidator(new QRegExpValidator(QRegExp("-?\\d{1,10}"), leValue));
            else
               leValue->setValidator(new QRegExpValidator(QRegExp("\\d{1,10}"), leValue));
         }
         else
            leValue->setValidator(new QIntValidator(min, max, leValue));
         leValue->setText("");
         break;
      }
   }
}

void UIMemorySearch::on_leValue_textChanged( const QString & text )
{
	(dbbButtons->button(QDialogButtonBox::Ok))->setEnabled(!text.isEmpty());
}

void UIMemorySearch::accept()
{
   QString value = leValue->text();
   u32 startAddress = leStartAddress->text().toUInt(0, 16);
   u32 endAddress = leEndAddress->text().toUInt(0, 16);

   if (startAddress >= endAddress)
   {
      CommonDialogs::information(QtYabause::translate("Invalid Start/End Address Combination"), QtYabause::translate("Error"));
      return;
   }

   QDialog::accept();
}

void UIMemorySearch::on_cbType_currentIndexChanged(int index)
{
   adjustSearchValueQValidator();
}
