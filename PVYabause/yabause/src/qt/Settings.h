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
#ifndef SETTINGS_H
#define SETTINGS_H
#include <QSettings>

#ifndef PROGRAM_NAME
#define PROGRAM_NAME PACKAGE
#endif

#ifndef PROGRAM_VERSION
#define PROGRAM_VERSION VERSION
#endif

class QMainWindow;

QString getDataDirPath();

class Settings : public QSettings
{
	Q_OBJECT

public:
	Settings( QObject* = 0 );
	~Settings();
	static void setIniInformations( const QString& = PROGRAM_NAME, const QString& = PROGRAM_VERSION );
	static QString programName();
	static QString programVersion();

	virtual void restoreState( QMainWindow* );
	virtual void saveState( QMainWindow* );
	virtual void setDefaultSettings();

protected:
	static QString mProgramName;
	static QString mProgramVersion;
};

#endif // PSETTINGS_H
