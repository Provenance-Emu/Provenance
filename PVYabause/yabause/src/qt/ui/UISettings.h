/*  Copyright 2005 Guillaume Duhamel
	Copyright 2005-2006, 2013 Theo Berkau
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
#ifndef UISETTINGS_H
#define UISETTINGS_H

#include "ui_UISettings.h"
#include "../QtYabause.h"
#include "UIYabause.h"

QStringList getCdDriveList();

class UISettings : public QDialog, public Ui::UISettings
{
	Q_OBJECT
	
public:
	UISettings( QList <supportedRes_struct> *supportedResolutions, QList <translation_struct> *translations, QWidget* parent = 0 );

protected:
	QList <supportedRes_struct> supportedRes;
	QList <translation_struct> trans;
	QList <QAction*> actionsList;

	void requestFile( const QString& caption, QLineEdit* edit, const QString& filters = QString() );
	void requestNewFile( const QString& caption, QLineEdit* edit, const QString& filters = QString() );
	void requestFolder( const QString& caption, QLineEdit* edit );
	void setupCdDrives();
	void loadCores();
	void loadSupportedResolutions();
	void loadTranslations();
	void loadShortcuts();
	void applyShortcuts();
	void loadSettings();
	void saveSettings();

protected slots:
	void tbBrowse_clicked();
	void on_cbInput_currentIndexChanged( int id );
	void on_cbCdRom_currentIndexChanged( int id );
	void on_cbClockSync_stateChanged( int state );
	void on_cbCartridge_currentIndexChanged( int id );
	void accept();
};

#endif // UISETTINGS_H
