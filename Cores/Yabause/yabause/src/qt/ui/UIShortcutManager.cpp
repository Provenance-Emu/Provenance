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
#include "UIShortcutManager.h"
#include "../CommonDialogs.h"
#include "../Settings.h"

#include <QDebug>
#include <QPainter>

MyItemDelegate::MyItemDelegate(QObject *parent) : QStyledItemDelegate(parent)
{
	installEventFilter(this);
}

bool MyItemDelegate::eventFilter ( QObject * editor, QEvent * event )
{
	QEvent::Type type = event->type();
	if (type == QEvent::KeyPress)
	{
		QKeyEvent *keyEvent = static_cast<QKeyEvent*>(event);
		QString text;

		int key = keyEvent->key();

		if(key == Qt::Key_Delete)
		{
			((QLineEdit *)editor)->setText("");
			return true;
		}

		if(key == Qt::Key_unknown)
			return true;

		if (keyEvent->key() == Qt::Key_Shift ||
			keyEvent->key() == Qt::Key_Control ||
			keyEvent->key() == Qt::Key_Meta ||
			keyEvent->key() == Qt::Key_Alt)
			text = QKeySequence((keyEvent->modifiers() & ~Qt::KeypadModifier)).toString();
		else
			text = QKeySequence((keyEvent->modifiers() & ~Qt::KeypadModifier) + keyEvent->key()).toString();
		((QLineEdit *)editor)->setText(text);
		return true;
	}
	return QStyledItemDelegate::eventFilter(editor, event);
}

UIShortcutManager::UIShortcutManager( QWidget* parent )
	: QTableWidget(parent)
{
	setItemDelegateForColumn(1, new MyItemDelegate());
}

UIShortcutManager::~UIShortcutManager()
{
}

