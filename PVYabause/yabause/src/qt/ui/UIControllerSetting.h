/*	Copyright 2008 Filipe Azevedo <pasnox@gmail.com>
   Copyright 2013 Theo Berkau <cwx@cyberwarriorx.com>

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
#ifndef UICONTROLLERSETTING_H
#define UICONTROLLERSETTING_H

#include <QDialog>
#include <QLabel>
#include <QToolButton>
#include "QtYabause.h"

#include <QMap>

class QTimer;

class UIControllerSetting : public QDialog
{
	Q_OBJECT

public:
	UIControllerSetting( PerInterface_struct* core, uint port, uint pad, uint perType, QWidget* parent = 0 );
	virtual ~UIControllerSetting();
	void setInfos(QLabel *lInfos);

protected:
	PerInterface_struct* mCore;
	uint mPort;
	uint mPad;
	u8 mPadKey;
	uint mPerType;
	QTimer* mTimer;
	QMap<QToolButton*, u8> mButtons;
	QMap<u8, QString> mNames;
	QMap<u8, u32> mScanMasks;
	QLabel *mlInfos;
	u32 scanFlags;

	void keyPressEvent( QKeyEvent* event );
	void mouseMoveEvent(QMouseEvent * event);
	void mousePressEvent(QMouseEvent * event);
	void setPadKey( u32 key );
	void loadPadSettings();
	void setScanFlags(u32 scanMask);

	virtual bool eventFilter( QObject* object, QEvent* event );

protected slots:
	void tbButton_clicked();
	void timer_timeout();
};

#endif // UICONTROLLERSETTING_H
