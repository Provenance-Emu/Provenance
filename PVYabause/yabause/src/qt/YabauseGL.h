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
#ifndef YABAUSEGL_H
#define YABAUSEGL_H

#ifdef HAVE_LIBGL
#include <QGLWidget>

class YabauseGL : public QGLWidget
#else
#include <QWidget>
#include <QImage>

class YabauseGL : public QWidget
#endif
{
	Q_OBJECT
	
public:
	YabauseGL( QWidget* parent = 0 );
	
	void updateView( const QSize& size = QSize() );
#ifndef HAVE_LIBGL
	virtual void swapBuffers();
	QImage grabFrameBuffer(bool withAlpha = false);
	virtual void paintEvent( QPaintEvent * event );
	void makeCurrent();
#endif

protected:
	virtual void showEvent( QShowEvent* event );
	virtual void resizeGL( int w, int h );
};

#endif // YABAUSEGL_H
