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

#include "UIDebugVDP2.h"
#include "UIDebugVDP2Viewer.h"
#include "CommonDialogs.h"

UIDebugVDP2::UIDebugVDP2( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

   if (Vdp2Regs)
   {
      updateInfoDisplay(Vdp2DebugStatsNBG0, cbNBG0Enabled, pteNBG0Info);
      updateInfoDisplay(Vdp2DebugStatsNBG1, cbNBG1Enabled, pteNBG1Info);
      updateInfoDisplay(Vdp2DebugStatsNBG2, cbNBG2Enabled, pteNBG2Info);
      updateInfoDisplay(Vdp2DebugStatsNBG3, cbNBG3Enabled, pteNBG3Info);
      updateInfoDisplay(Vdp2DebugStatsRBG0, cbRBG0Enabled, pteRBG0Info);
      updateInfoDisplay(Vdp2DebugStatsGeneral, cbDisplayEnabled, pteGeneralInfo);
   }

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIDebugVDP2::updateInfoDisplay(void (*debugStats)(char *, int *), QCheckBox *cb, QPlainTextEdit *pte)
{
   char tempstr[2048];
   int isScreenEnabled=false;

   debugStats(tempstr, &isScreenEnabled);

   if (isScreenEnabled)
   {
      cb->setChecked(true);
      pte->clear();
      pte->appendPlainText(tempstr);
      pte->moveCursor(QTextCursor::Start);
   }
   else
      cb->setChecked(false);

}

void UIDebugVDP2::on_pbViewer_clicked()
{
	UIDebugVDP2Viewer( this ).exec();
}
