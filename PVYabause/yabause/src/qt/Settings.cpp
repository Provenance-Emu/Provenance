/*  Copyright 2005 Guillaume Duhamel
    Copyright 2005-2006 Theo Berkau
	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>

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
#include "Settings.h"

#include <QApplication>
#include <QDir>
#include <QFile>
#include <QMainWindow>
#include <QDesktopServices>

QString Settings::mProgramName;
QString Settings::mProgramVersion;

QString getDataDirPath()
{
#if defined Q_OS_WIN
	// Use some wizardry so we can get our data in AppData
   QString oldApplicationName = QCoreApplication::applicationName();   
   QCoreApplication::setApplicationName("yabause");
#if QT_VERSION >= 0x04FF00
   QString path = QStandardPaths::writableLocation(QStandardPaths::DataLocation);
#else
	QString path = QDesktopServices::storageLocation(QDesktopServices::DataLocation);
#endif
   QCoreApplication::setApplicationName(oldApplicationName);
	return path;
#else
	return QApplication::applicationDirPath();
#endif
}

QString getIniFile( const QString& s )
{
#if defined Q_OS_MAC
	return QString( "%1/../%2.ini" ).arg( QApplication::applicationDirPath() ).arg( s );
#elif defined Q_OS_WIN
	/* We used to store the ini file in the application directory, before moving to the
	correct location, but some users like it better the old way... so if we find a .ini
	file in the application directory, we're using it */
	QString oldinifile = QString( "%1/%2.ini" ).arg( QApplication::applicationDirPath() ).arg( s );
	if ( QFile::exists( oldinifile )) return oldinifile;

	return QString( "%1/%2.ini" ).arg( getDataDirPath() ).arg(s);
#else
	/*
	We used to store the ini file in ~/.$SOMETHING/$SOMETHING.ini, were $SOMETHING could
	be at least yabause or yabause-qt
	With release 0.9.12 we moved to the XDG compliant location ~/.config/yabause/qt/yabause.ini
	and we don't want this location to depends on the program name anymore.
	This code is trying to copy the content from the old location to the new.
	In the future, we may drop support for the old location and rewrite the following to:

	return QString( "%1/.config/yabause/qt/yabause.ini" ).arg( QDir::homePath() );
	*/

	QString xdginifile = QString( "%1/.config/yabause/qt/yabause.ini" ).arg( QDir::homePath() );
	QString oldinifile = QString( "%1/.%2/%2.ini" ).arg( QDir::homePath() ).arg( s );

	if ( not QFile::exists( xdginifile ) )
	{
		QString xdgpath = QString( "%1/.config/yabause/qt" ).arg( QDir::homePath() );
		if ( ! QFile::exists( xdgpath ) )
		{
			// for some reason, Qt doesn't provide a static mkpath method O_o
			QDir dir;
			dir.mkpath( xdgpath );
		}

		if ( QFile::exists( oldinifile ) )
			QFile::copy( oldinifile, xdginifile );
	}

	return xdginifile;
#endif
}

Settings::Settings( QObject* o )
	: QSettings( QDir::toNativeSeparators( getIniFile( mProgramName ) ), QSettings::IniFormat, o )
{
	/*
	This used to be "beginGroup( mProgramVersion );" so users would lose their
	config with each new release...
	*/
	beginGroup( "0.9.11" );
}

Settings::~Settings()
{ endGroup(); }

void Settings::setIniInformations( const QString& pName, const QString& pVersion )
{
	mProgramName = pName;
	mProgramVersion = pVersion;
}

QString Settings::programName()
{ return mProgramName; }

QString Settings::programVersion()
{ return mProgramVersion; }

void Settings::restoreState( QMainWindow* w )
{
	if ( !w )
		return;
	w->restoreState( value( "MainWindow/State" ).toByteArray() );
	QPoint p = value( "MainWindow/Position" ).toPoint();
	QSize s = value( "MainWindow/Size" ).toSize();
	if ( !p.isNull() && !s.isNull() )
	{
		w->resize( s );
		w->move( p );
	}
	if ( value( "MainWindow/Maximized", true ).toBool() )
		w->showMaximized();
}

void Settings::saveState( QMainWindow* w )
{
	if ( !w )
		return;
	setValue( "MainWindow/Maximized", w->isMaximized() );
	setValue( "MainWindow/Position", w->pos() );
	setValue( "MainWindow/Size", w->size() );
	setValue( "MainWindow/State", w->saveState() );
}

void Settings::setDefaultSettings()
{
}
