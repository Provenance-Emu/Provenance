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
#ifndef YABAUSETHREAD_H
#define YABAUSETHREAD_H

#include <QThread>
#include <QSize>
#include <QMutexLocker>

#include "QtYabause.h"

class YabauseThread : public QObject
{
	Q_OBJECT
	
public:
	YabauseThread( QObject* owner = 0 );
	virtual ~YabauseThread();
	
	yabauseinit_struct* yabauseConf();
	bool emulationRunning();
	bool emulationPaused();
	inline int init() const { return mInit; }

protected:
	yabauseinit_struct mYabauseConf;
	bool showFPS;
	QMutex mMutex;
	bool mPause;
	int mTimerId;
	int mInit;
	
	void initEmulation();
	void deInitEmulation();
	void resetYabauseConf();
	void timerEvent( QTimerEvent* );

public slots:
	bool pauseEmulation( bool pause, bool reset );
	bool resetEmulation();
	void reloadControllers();
	void reloadClock();
	void reloadSettings();

signals:
	void requestSize( const QSize& size );
	void requestFullscreen( bool fullscreen );
	void requestVolumeChange( int volume );
	void error( const QString& error, bool internal = true );
	void pause( bool paused );
	void reset();
	void toggleEmulateMouse( bool enable );
};

#endif // YABAUSETHREAD_H
