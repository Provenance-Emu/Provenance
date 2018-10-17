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
#ifndef COMMONDIALOGS_H
#define COMMONDIALOGS_H

#include <QApplication>
#include <QMessageBox>
#include <QInputDialog>
#include <QFileDialog>

namespace CommonDialogs
{
	bool question( const QString& message, const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Question..." ) );
	void warning( const QString& message, const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Warning..." ) );
	void information( const QString& message, const QString& caption = "Information..." );
	QString getItem( const QStringList items, const QString& label, const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Get Item..." ) );
	QString getSaveFileName( const QString& directory = QString(), const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Get Save File Name..." ), const QString& filter = QString() );
	QString getOpenFileName( const QString& directory = QString(), const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Get Open File Name..." ), const QString& filter = QString() );
	QString getExistingDirectory( const QString& directory = QString(), const QString& caption = QT_TRANSLATE_NOOP( "CommonDialogs", "Get Existing Directory..." ), QFileDialog::Options options = QFileDialog::ShowDirsOnly );
};

#endif // COMMONDIALOGS_H
