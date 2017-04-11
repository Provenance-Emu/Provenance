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
#include "CommonDialogs.h"
#include "QtYabause.h"

bool CommonDialogs::question( const QString& m, const QString& c )
{ return QMessageBox::question( QApplication::activeWindow(), c, m, QMessageBox::Yes | QMessageBox::No, QMessageBox::No ) == QMessageBox::Yes; }

void CommonDialogs::warning( const QString& m, const QString& c )
{ QMessageBox::warning( QApplication::activeWindow(), c, m ); }

void CommonDialogs::information( const QString& m, const QString& c )
{ QMessageBox::information( QApplication::activeWindow(), QtYabause::translate( c ), m ); }

QString CommonDialogs::getItem( const QStringList i, const QString& l, const QString& c )
{
	bool b;
	const QString s = QInputDialog::getItem( QApplication::activeWindow(), c, l, i, 0, false, &b );
	return b ? s : QString();
}

QString CommonDialogs::getSaveFileName( const QString& d, const QString& c, const QString& f )
{ return QFileDialog::getSaveFileName( QApplication::activeWindow(), c, d, f ); }

QString CommonDialogs::getOpenFileName( const QString& d, const QString& c, const QString& f )
{ return QFileDialog::getOpenFileName( QApplication::activeWindow(), c, d, f ); }

QString CommonDialogs::getExistingDirectory( const QString& d, const QString& c, QFileDialog::Options o )
{ return QFileDialog::getExistingDirectory( QApplication::activeWindow(), c, d, o ); }
