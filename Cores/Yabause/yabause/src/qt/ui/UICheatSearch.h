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
#ifndef UICHEATSEARCH_H
#define UICHEATSEARCH_H

#include "ui_UICheatSearch.h"
#include "../QtYabause.h"

typedef struct
{
   result_struct *results;
   u32 numResults;
   u32 startAddr;
   u32 endAddr;
} cheatsearch_struct;

class UICheatSearch : public QDialog, public Ui::UICheatSearch
{
	Q_OBJECT

public:
   UICheatSearch( QWidget* p, QList <cheatsearch_struct> *search, int searchType);
   QList <cheatsearch_struct> *getSearchVariables(int *searchType);
protected:
   QList <cheatsearch_struct> search;

   int searchType;

   void getSearchTypes();
   void setSearchTypes();
   void listResults();
   void adjustSearchValueQValidator();
protected slots:
   void on_twSearchResults_itemSelectionChanged();
	void on_leSearchValue_textChanged( const QString & text );
   void on_pbRestart_clicked();
   void on_pbSearch_clicked();
   void on_pbAddCheat_clicked();
   void on_rbUnsigned_toggled(bool checked);
   void on_rbSigned_toggled(bool checked);
   void on_rb8Bit_toggled(bool checked);
   void on_rb16Bit_toggled(bool checked);
   void on_rb32Bit_toggled(bool checked);
};

#endif // UICHEATSEARCH_H
