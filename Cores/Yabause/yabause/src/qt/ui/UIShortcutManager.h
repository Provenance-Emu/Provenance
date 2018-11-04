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
#ifndef UISHORTCUTMANAGER_H
#define UISHORTCUTMANAGER_H

#include <QTableWidget>
#include <QStyledItemDelegate>
#include <QEvent>
#include <QKeyEvent>
#include <QLineEdit>
#include <QPushButton>
#include "../QtYabause.h"

class MyItemDelegate : public QStyledItemDelegate
{
	Q_OBJECT
public:
	MyItemDelegate(QObject *parent = 0);
	bool eventFilter ( QObject * editor, QEvent * event );
};

class UIShortcutManager : public QTableWidget
{
	Q_OBJECT

public:
	UIShortcutManager( QWidget* parent = 0 );
	virtual ~UIShortcutManager();


protected:

protected slots:
};

#endif // UISHORTCUTMANAGER_H
