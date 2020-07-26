/*	Copyright 2012 Theo Berkau <cwx@cyberwarriorx.com>

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

#include "UIDebugVDP2Viewer.h"
#include "CommonDialogs.h"

#include <QImageWriter>
#include <QGraphicsPixmapItem>

UIDebugVDP2Viewer::UIDebugVDP2Viewer( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

   QGraphicsScene *scene=new QGraphicsScene(this);
   gvScreen->setScene(scene);

   vdp2texture = NULL;
	width = 0;
	height = 0;

   cbScreen->addItem("NBG0/RBG1");
   cbScreen->addItem("NBG1");
   cbScreen->addItem("NBG2");
   cbScreen->addItem("NBG3");
   cbScreen->addItem("RBG0");
   cbScreen->setCurrentIndex(0);

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UIDebugVDP2Viewer::on_cbScreen_currentIndexChanged ( int index )
{   
	if (!Vdp2Regs)
		return;

   if (vdp2texture)
      free(vdp2texture);

   vdp2texture = Vdp2DebugTexture(index, &width, &height);
   pbSaveAsBitmap->setEnabled(vdp2texture ? true : false);

   // Redraw screen
   QGraphicsScene *scene = gvScreen->scene();
#ifdef USE_RGB_555
   QImage img((uchar *)vdp2texture, width, height, QImage::Format_RGB555);
#elif USE_RGB_565
   QImage img((uchar *)vdp2texture, width, height, QImage::Format_RGB16);
#else
   QImage img((uchar *)vdp2texture, width, height, QImage::Format_ARGB32);
#endif
   QPixmap pixmap = QPixmap::fromImage(img.rgbSwapped());
   scene->clear();
   scene->addPixmap(pixmap);
   scene->setSceneRect(scene->itemsBoundingRect());
   gvScreen->fitInView(scene->sceneRect());
   gvScreen->invalidateScene();
}

void UIDebugVDP2Viewer::on_pbSaveAsBitmap_clicked ()
{
	QStringList filters;
	foreach ( QByteArray ba, QImageWriter::supportedImageFormats() )
		if ( !filters.contains( ba, Qt::CaseInsensitive ) )
			filters << QString( ba ).toLower();
	for ( int i = 0; i < filters.count(); i++ )
		filters[i] = QtYabause::translate( "%1 Images (*.%2)" ).arg( filters[i].toUpper() ).arg( filters[i] );

	if (!vdp2texture)
		return;
	
	// take screenshot of gl view
   QImage img((uchar *)vdp2texture, width, width, QImage::Format_ARGB32);
   img = img.rgbSwapped();
	
	// request a file to save to to user
	const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for your bitmap" ), filters.join( ";;" ) );
	
	// write image if ok
	if ( !s.isEmpty() )
		if ( !img.save( s ) )
			CommonDialogs::information( QtYabause::translate( "An error occured while writing file." ) );
}

