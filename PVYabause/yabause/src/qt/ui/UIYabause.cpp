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
#include "UIYabause.h"
#include "../Settings.h"
#include "../VolatileSettings.h"
#include "UISettings.h"
#include "UIBackupRam.h"
#include "UICheats.h"
#include "UICheatSearch.h"
#include "UIDebugSH2.h"
#include "UIDebugVDP1.h"
#include "UIDebugVDP2.h"
#include "UIDebugM68K.h"
#include "UIDebugSCUDSP.h"
#include "UIDebugSCSP.h"
#include "UIDebugSCSPDSP.h"
#include "UIMemoryEditor.h"
#include "UIMemoryTransfer.h"
#include "UIAbout.h"
#include "../YabauseGL.h"
#include "../QtYabause.h"
#include "../CommonDialogs.h"

#include <QKeyEvent>
#include <QTextEdit>
#include <QDockWidget>
#include <QImageWriter>
#include <QUrl>
#include <QDesktopServices>
#include <QDateTime>

#include <QDebug>

extern "C" {
extern VideoInterface_struct *VIDCoreList[];
}

//#define USE_UNIFIED_TITLE_TOOLBAR

void qAppendLog( const char* s )
{
	UIYabause* ui = QtYabause::mainWindow( false );

	if ( ui ) {
		ui->appendLog( s );
	}
	else {
		qWarning( "%s", s );
	}
}

UIYabause::UIYabause( QWidget* parent )
	: QMainWindow( parent )
{
	mInit = false;
   search.clear();
	searchType = 0;

	// setup dialog
	setupUi( this );
	toolBar->insertAction( aFileSettings, mFileSaveState->menuAction() );
	toolBar->insertAction( aFileSettings, mFileLoadState->menuAction() );
	toolBar->insertSeparator( aFileSettings );
	setAttribute( Qt::WA_DeleteOnClose );
#ifdef USE_UNIFIED_TITLE_TOOLBAR
	setUnifiedTitleAndToolBarOnMac( true );
#endif
	fSound->setParent( 0, Qt::Popup );
	fVideoDriver->setParent( 0, Qt::Popup );
	fSound->installEventFilter( this );
	fVideoDriver->installEventFilter( this );
	// Get Screen res list
	getSupportedResolutions();
	// fill combo driver
	cbVideoDriver->blockSignals( true );
	for ( int i = 0; VIDCoreList[i] != NULL; i++ )
		cbVideoDriver->addItem( VIDCoreList[i]->Name, VIDCoreList[i]->id );
	cbVideoDriver->blockSignals( false );
	// create glcontext
	mYabauseGL = new YabauseGL( this );
	// and set it as central application widget
	setCentralWidget( mYabauseGL );
	// create log widget
	teLog = new QTextEdit( this );
	teLog->setReadOnly( true );
	teLog->setWordWrapMode( QTextOption::NoWrap );
	teLog->setVerticalScrollBarPolicy( Qt::ScrollBarAlwaysOn );
	teLog->setHorizontalScrollBarPolicy( Qt::ScrollBarAlwaysOn );
	mLogDock = new QDockWidget( this );
	mLogDock->setWindowTitle( "Log" );
	mLogDock->setWidget( teLog );
	addDockWidget( Qt::BottomDockWidgetArea, mLogDock );
	mLogDock->setVisible( false );
	mCanLog = true;
	oldMouseX = oldMouseY = 0;

#ifndef SH2_TRACE
	aTraceLogging->setVisible(false);
#endif

	// create emulator thread
	mYabauseThread = new YabauseThread( this );
	// create hide mouse timer
	hideMouseTimer = new QTimer();
	// create mouse cursor timer
	mouseCursorTimer = new QTimer();
	// connections
	connect( mYabauseThread, SIGNAL( requestSize( const QSize& ) ), this, SLOT( sizeRequested( const QSize& ) ) );
	connect( mYabauseThread, SIGNAL( requestFullscreen( bool ) ), this, SLOT( fullscreenRequested( bool ) ) );
	connect( mYabauseThread, SIGNAL( requestVolumeChange( int ) ), this, SLOT( on_sVolume_valueChanged( int ) ) );
	connect( aViewLog, SIGNAL( toggled( bool ) ), mLogDock, SLOT( setVisible( bool ) ) );
	connect( mLogDock->toggleViewAction(), SIGNAL( toggled( bool ) ), aViewLog, SLOT( setChecked( bool ) ) );
	connect( mYabauseThread, SIGNAL( error( const QString&, bool ) ), this, SLOT( errorReceived( const QString&, bool ) ) );
	connect( mYabauseThread, SIGNAL( pause( bool ) ), this, SLOT( pause( bool ) ) );
	connect( mYabauseThread, SIGNAL( reset() ), this, SLOT( reset() ) );
	connect( hideMouseTimer, SIGNAL( timeout() ), this, SLOT( hideMouse() ));
	connect( mouseCursorTimer, SIGNAL( timeout() ), this, SLOT( cursorRestore() ));
	connect( mYabauseThread, SIGNAL( toggleEmulateMouse( bool ) ), this, SLOT( toggleEmulateMouse( bool ) ) );

	// Load shortcuts
	VolatileSettings* vs = QtYabause::volatileSettings();
	QList<QAction *> actions = findChildren<QAction *>();
	foreach ( QAction* action, actions )
	{
		if (action->text().isEmpty())
			continue;

		QString text = vs->value(QString("Shortcuts/") + action->text(), "").toString();
		if (text.isEmpty())
			continue;
		action->setShortcut(text);
	}

	// retranslate widgets
	QtYabause::retranslateWidget( this );

	QList<QAction *> actionList = menubar->actions();
	for(int i = 0;i < actionList.size();i++) {
		addAction(actionList.at(i));
	}

	restoreGeometry( vs->value("General/Geometry" ).toByteArray() );
	mYabauseGL->setMouseTracking(true);
	setMouseTracking(true);
	mouseXRatio = mouseYRatio = 1.0;
	emulateMouse = false;
	mouseSensitivity = vs->value( "Input/GunMouseSensitivity", 100 ).toInt();
	showMenuBarHeight = menubar->height();
	translations = QtYabause::getTranslationList();

	VIDSoftSetBilinear(QtYabause::settings()->value( "Video/Bilinear", false ).toBool());
}

UIYabause::~UIYabause()
{
	mCanLog = false;
}

void UIYabause::showEvent( QShowEvent* e )
{
	QMainWindow::showEvent( e );

	if ( !mInit )
	{
		LogStart();
		LogChangeOutput( DEBUG_CALLBACK, (char*)qAppendLog );
		VolatileSettings* vs = QtYabause::volatileSettings();

		if ( vs->value( "View/Menubar" ).toInt() == BD_ALWAYSHIDE )
			menubar->hide();
		if ( vs->value( "View/Toolbar" ).toInt() == BD_ALWAYSHIDE )
			toolBar->hide();
		if ( vs->value( "autostart" ).toBool() )
			aEmulationRun->trigger();
		aEmulationFrameSkipLimiter->setChecked( vs->value( "General/EnableFrameSkipLimiter" ).toBool() );
		aViewFPS->setChecked( vs->value( "General/ShowFPS" ).toBool() );
		mInit = true;
	}
}

void UIYabause::closeEvent( QCloseEvent* e )
{
	aEmulationPause->trigger();
	LogStop();

	if (isFullScreen())
		// Need to switch out of full screen or the geometry settings get saved
		fullscreenRequested( false );
	Settings* vs = QtYabause::settings();
	vs->setValue( "General/Geometry", saveGeometry() );
	vs->sync();

	QMainWindow::closeEvent( e );
}

void UIYabause::keyPressEvent( QKeyEvent* e )
{ PerKeyDown( e->key() ); }

void UIYabause::keyReleaseEvent( QKeyEvent* e )
{ PerKeyUp( e->key() ); }

void UIYabause::mousePressEvent( QMouseEvent* e )
{
	PerKeyDown( (1 << 31) | e->button() );
}

void UIYabause::mouseReleaseEvent( QMouseEvent* e )
{
	PerKeyUp( (1 << 31) | e->button() );
}

void UIYabause::hideMouse()
{
	this->setCursor(Qt::BlankCursor);
	hideMouseTimer->stop();
}

void UIYabause::cursorRestore()
{
	this->setCursor(Qt::ArrowCursor);
	mouseCursorTimer->stop();
}

void UIYabause::mouseMoveEvent( QMouseEvent* e )
{
	int x = (e->x()-oldMouseX)*mouseXRatio;
	int y = (oldMouseY-e->y())*mouseYRatio;
	int minAdj = mouseSensitivity/100;

	// If minimum movement is less than x, wait until next pass to apply
	if (abs(x) < minAdj) x = 0;
	if (abs(y) < minAdj) y = 0;

	PerAxisMove((1 << 30), x, y);

	oldMouseX = oldMouseX+(x/mouseXRatio);
	oldMouseY = oldMouseY-(y/mouseYRatio);

	VolatileSettings* vs = QtYabause::volatileSettings();

	if (!isFullScreen())
	{
		if (emulateMouse)
		{
			int menuToolHeight = menubar->height() + toolBar->height();
			if (oldMouseY > menuToolHeight)
				this->setCursor(Qt::BlankCursor);
			else
				this->setCursor(Qt::ArrowCursor);
			return;
		}
		else
			this->setCursor(Qt::ArrowCursor);
	}
	else
	{
		if (vs->value( "View/Menubar" ).toInt() == BD_SHOWONFSHOVER)
		{
			if (e->y() < showMenuBarHeight)
				menubar->show();
			else
			{
				menubar->hide();
				if (emulateMouse)
				{
					this->setCursor(Qt::BlankCursor);
					return;
				}
			}
		}
		else if (emulateMouse)
		{
			this->setCursor(Qt::BlankCursor);
			return;
		}

		hideMouseTimer->start(3 * 1000);
		this->setCursor(Qt::ArrowCursor);
	}
}

void UIYabause::resizeEvent( QResizeEvent* event )
{
	if (event->oldSize().width() != event->size().width())
		fixAspectRatio(event->size().width());

	QMainWindow::resizeEvent( event );
}

void UIYabause::swapBuffers()
{
	mYabauseGL->swapBuffers();
	mYabauseGL->makeCurrent();
}

void UIYabause::appendLog( const char* s )
{
	if (! mCanLog)
	{
		qWarning( "%s", s );
		return;
	}

	teLog->moveCursor( QTextCursor::End );
	teLog->append( s );

	VolatileSettings* vs = QtYabause::volatileSettings();
	if (( !mLogDock->isVisible( )) && ( vs->value( "View/LogWindow" ).toInt() == 1 )) {
		mLogDock->setVisible( true );
	}
}

bool UIYabause::eventFilter( QObject* o, QEvent* e )
{
	if ( e->type() == QEvent::Hide )
		setFocus();
	return QMainWindow::eventFilter( o, e );
}

void UIYabause::errorReceived( const QString& error, bool internal )
{
	if ( internal ) {
		appendLog( error.toLocal8Bit().constData() );
	}
	else {
		CommonDialogs::information( error );
	}
}

void UIYabause::sizeRequested( const QSize& s )
{
	int heightOffset = toolBar->height()+menubar->height();
	int width, height;
	if (s.isNull())
	{
		return;
	}
	else
	{
		width=s.width();
		height=s.height();
	}

	mouseXRatio = 320.0 / (float)width * 2.0 * (float)mouseSensitivity / 100.0;
	mouseYRatio = 240.0 / (float)height * 2.0 * (float)mouseSensitivity / 100.0;

	// Compensate for menubar and toolbar
	VolatileSettings* vs = QtYabause::volatileSettings();
	if (vs->value( "View/Menubar" ).toInt() != BD_ALWAYSHIDE)
		height += menubar->height();
	if (vs->value( "View/Toolbar" ).toInt() != BD_ALWAYSHIDE)
		height += toolBar->height();

	resize( width, height );
}

void UIYabause::fixAspectRatio( int width )
{
	int aspectRatio = QtYabause::volatileSettings()->value( "Video/AspectRatio").toInt();

	switch( aspectRatio )
	{
		case 0:
			setMaximumSize( QWIDGETSIZE_MAX, QWIDGETSIZE_MAX );
			setMinimumSize( 0,0 );
			break;
		case 1:
		case 2:
		{
			int heightOffset = toolBar->height()+menubar->height();
			int height;

			if ( aspectRatio == 1 )
				height = 3 * ((float) width / 4);
			else
				height = 9 * ((float) width / 16);

			mouseYRatio = 240.0 / (float)height * 2.0 * (float)mouseSensitivity / 100.0;

			// Compensate for menubar and toolbar
			VolatileSettings* vs = QtYabause::volatileSettings();
			if (vs->value( "View/Menubar" ).toInt() != BD_ALWAYSHIDE)
				height += menubar->height();
			if (vs->value( "View/Toolbar" ).toInt() != BD_ALWAYSHIDE)
				height += toolBar->height();

			setFixedHeight( height );
			break;
		}
	}
}

void UIYabause::getSupportedResolutions()
{
#if defined Q_OS_WIN
	DEVMODE devMode;
	BOOL result = TRUE;
	DWORD currentSettings = 0;
	devMode.dmSize = sizeof(DEVMODE);

	supportedResolutions.clear();

	while (result)
	{
		result = EnumDisplaySettings(NULL, currentSettings, &devMode);
		if (result && devMode.dmBitsPerPel == 32)
		{
			supportedRes_struct res;
			res.width = devMode.dmPelsWidth;
			res.height = devMode.dmPelsHeight;
			res.bpp = devMode.dmBitsPerPel;
			res.freq = devMode.dmDisplayFrequency;

			supportedResolutions.append(res);
		}
		currentSettings++;
	}
#elif HAVE_LIBXRANDR
	ResolutionList list;
	supportedRes_struct res;

	list = ScreenGetResolutions();

	while(0 == ScreenNextResolution(list, &res))
		supportedResolutions.append(res);
#endif
}

int UIYabause::isResolutionValid( int width, int height, int bpp, int freq )
{
	for (int i = 0; i < supportedResolutions.count(); i++)
	{
		if (supportedResolutions[i].width == width &&
			supportedResolutions[i].height == height)
			return i;
	}

	return -1;
}

int UIYabause::findBestVideoFreq( int width, int height, int bpp, int videoFormat )
{
	// Try to use a frequency close to 60 hz for NTSC, 75 hz for PAL
	if (videoFormat == VIDEOFORMATTYPE_PAL && isResolutionValid( width, height, bpp, 75 ) > 0)
		return 75;
	else if (videoFormat == VIDEOFORMATTYPE_NTSC && isResolutionValid( width, height, bpp, 60 ) > 0)
		return 60;
	else
	{
		// Since we can't use the frequency we want, use the first one available
		int i=isResolutionValid( width, height, bpp, -1 );
		if (i < 0)
			return -1;
		return supportedResolutions[i].freq;
	}
}

void UIYabause::toggleFullscreen( int width, int height, bool f, int videoFormat )
{
	// Make sure setting is valid
	if (f && isResolutionValid( width, height, -1, -1 ) < 0)
		return;

#if defined Q_OS_WIN
	if (f)
	{
		DEVMODE dmScreenSettings;
		memset (&dmScreenSettings, 0, sizeof (dmScreenSettings));

		int freq = findBestVideoFreq( width, height, 32, videoFormat );

		if (freq < 0)
			return;

		dmScreenSettings.dmSize = sizeof (dmScreenSettings);
		dmScreenSettings.dmPelsWidth = width;
		dmScreenSettings.dmPelsHeight = height;
		dmScreenSettings.dmBitsPerPel = 32;
		dmScreenSettings.dmDisplayFrequency = freq;
		dmScreenSettings.dmFields = DM_BITSPERPEL | DM_PELSWIDTH | DM_PELSHEIGHT;
		ChangeDisplaySettings(&dmScreenSettings, CDS_FULLSCREEN);
	}
	else
		ChangeDisplaySettings(NULL, 0);

#elif HAVE_LIBXRANDR
	if (f)
	{
		int i = isResolutionValid(width, height, 32, -1);
		ScreenChangeResolution(&supportedResolutions[i]);
	}
	else
	{
		ScreenRestoreResolution();
	}
#endif
}

void UIYabause::fullscreenRequested( bool f )
{
	if ( isFullScreen() && !f )
	{
#ifdef USE_UNIFIED_TITLE_TOOLBAR
		setUnifiedTitleAndToolBarOnMac( true );
#endif
		toggleFullscreen(0, 0, false, -1 );
		showNormal();

		VolatileSettings* vs = QtYabause::volatileSettings();
		int menubarHide = vs->value( "View/Menubar" ).toInt();
		if ( menubarHide == BD_HIDEFS ||
			  menubarHide == BD_SHOWONFSHOVER)
			menubar->show();
		if ( vs->value( "View/Toolbar" ).toInt() == BD_HIDEFS )
			toolBar->show();

		setCursor(Qt::ArrowCursor);
		hideMouseTimer->stop();
	}
	else if ( !isFullScreen() && f )
	{
#ifdef USE_UNIFIED_TITLE_TOOLBAR
		setUnifiedTitleAndToolBarOnMac( false );
#endif
		VolatileSettings* vs = QtYabause::volatileSettings();

		setMaximumSize( QWIDGETSIZE_MAX, QWIDGETSIZE_MAX );
		setMinimumSize( 0,0 );

		toggleFullscreen(vs->value("Video/FullscreenWidth").toInt(), vs->value("Video/FullscreenHeight").toInt(),
						f, vs->value("Video/VideoFormat").toInt());

		showFullScreen();

		if ( vs->value( "View/Menubar" ).toInt() == BD_HIDEFS )
			menubar->hide();
		if ( vs->value( "View/Toolbar" ).toInt() == BD_HIDEFS )
			toolBar->hide();

		hideMouseTimer->start(3 * 1000);
	}
	if ( aViewFullscreen->isChecked() != f )
		aViewFullscreen->setChecked( f );
	aViewFullscreen->setIcon( QIcon( f ? ":/actions/no_fullscreen.png" : ":/actions/fullscreen.png" ) );
}

void UIYabause::refreshStatesActions()
{
	// reset save actions
	foreach ( QAction* a, findChildren<QAction*>( QRegExp( "aFileSaveState*" ) ) )
	{
		if ( a == aFileSaveStateAs )
			continue;
		int i = a->objectName().remove( "aFileSaveState" ).toInt();
		a->setText( QString( "%1 ... " ).arg( i ) );
		a->setToolTip( a->text() );
		a->setStatusTip( a->text() );
		a->setData( i );
	}
	// reset load actions
	foreach ( QAction* a, findChildren<QAction*>( QRegExp( "aFileLoadState*" ) ) )
	{
		if ( a == aFileLoadStateAs )
			continue;
		int i = a->objectName().remove( "aFileLoadState" ).toInt();
		a->setText( QString( "%1 ... " ).arg( i ) );
		a->setToolTip( a->text() );
		a->setStatusTip( a->text() );
		a->setData( i );
		a->setEnabled( false );
	}
	// get states files of this game
	const QString serial = QtYabause::getCurrentCdSerial();
	const QString mask = QString( "%1_*.yss" ).arg( serial );
	const QString statesPath = QtYabause::volatileSettings()->value( "General/SaveStates", getDataDirPath() ).toString();
	QRegExp rx( QString( mask ).replace( '*', "(\\d+)") );
	QDir d( statesPath );
	foreach ( const QFileInfo& fi, d.entryInfoList( QStringList( mask ), QDir::Files | QDir::Readable, QDir::Name | QDir::IgnoreCase ) )
	{
		if ( rx.exactMatch( fi.fileName() ) )
		{
			int slot = rx.capturedTexts().value( 1 ).toInt();
			const QString caption = QString( "%1 %2 " ).arg( slot ).arg( fi.lastModified().toString( Qt::SystemLocaleDate ) );
			// update save state action
			if ( QAction* a = findChild<QAction*>( QString( "aFileSaveState%1" ).arg( slot ) ) )
			{
				a->setText( caption );
				a->setToolTip( caption );
				a->setStatusTip( caption );
				// update load state action
				a = findChild<QAction*>( QString( "aFileLoadState%1" ).arg( slot ) );
				a->setText( caption );
				a->setToolTip( caption );
				a->setStatusTip( caption );
				a->setEnabled( true );
			}
		}
	}
}

void UIYabause::on_aFileSettings_triggered()
{
	Settings *s = (QtYabause::settings());
	QHash<QString, QVariant> hash;
	const QStringList keys = s->allKeys();
	Q_FOREACH(QString key, keys) {
		hash[key] = s->value(key);
	}

	YabauseLocker locker( mYabauseThread );
	if ( UISettings( &supportedResolutions, &translations, window() ).exec() )
	{
		VolatileSettings* vs = QtYabause::volatileSettings();
		aEmulationFrameSkipLimiter->setChecked( vs->value( "General/EnableFrameSkipLimiter" ).toBool() );
		aViewFPS->setChecked( vs->value( "General/ShowFPS" ).toBool() );
		mouseSensitivity = vs->value( "Input/GunMouseSensitivity" ).toInt();

		if(isFullScreen())
		{
			if ( vs->value( "View/Menubar" ).toInt() == BD_HIDEFS || vs->value( "View/Menubar" ).toInt() == BD_ALWAYSHIDE )
				menubar->hide();
			else
				menubar->show();

			if ( vs->value( "View/Toolbar" ).toInt() == BD_HIDEFS || vs->value( "View/Toolbar" ).toInt() == BD_ALWAYSHIDE )
				toolBar->hide();
			else
				toolBar->show();
		}
		else
		{
			if ( vs->value( "View/Menubar" ).toInt() == BD_ALWAYSHIDE )
				menubar->hide();
			else
				menubar->show();

			if ( vs->value( "View/Toolbar" ).toInt() == BD_ALWAYSHIDE )
				toolBar->hide();
			else
				toolBar->show();
		}


		//only reset if bios, region, cart,  back up, mpeg, sh2, m68k are changed
		Settings *ss = (QtYabause::settings());
		QHash<QString, QVariant> newhash;
		const QStringList newkeys = ss->allKeys();
		Q_FOREACH(QString key, newkeys) {
			newhash[key] = ss->value(key);
		}
		if(newhash["General/Bios"]!=hash["General/Bios"] ||
			newhash["Advanced/Region"]!=hash["Advanced/Region"] ||
			newhash["Cartridge/Type"]!=hash["Cartridge/Type"] ||
			newhash["Memory/Path"]!=hash["Memory/Path"] ||
			newhash["MpegROM/Path" ]!=hash["MpegROM/Path" ] ||
			newhash["Advanced/SH2Interpreter" ]!=hash["Advanced/SH2Interpreter" ] ||
			newhash["General/CdRom"]!=hash["General/CdRom"] ||
			newhash["General/CdRomISO"]!=hash["General/CdRomISO"] ||
			newhash["General/ClockSync"]!=hash["General/ClockSync"] ||
			newhash["General/FixedBaseTime"]!=hash["General/FixedBaseTime"]
		)
		{
			if ( mYabauseThread->pauseEmulation( true, true ) )
				refreshStatesActions();
			return;
		}
#ifdef HAVE_LIBMINI18N
		if(newhash["General/Translation"] != hash["General/Translation"])
		{
			mini18n_close();
			retranslateUi(this);
			if ( QtYabause::setTranslationFile() == -1 )
				qWarning( "Can't set translation file" );
			QtYabause::retranslateApplication();
		}
#endif
		if(newhash["Video/VideoCore"] != hash["Video/VideoCore"])
			on_cbVideoDriver_currentIndexChanged(newhash["Video/VideoCore"].toInt());

		if(newhash["General/ShowFPS"] != hash["General/ShowFPS"])
			SetOSDToggle(newhash["General/ShowFPS"].toBool());

		if (newhash["Sound/SoundCore"] != hash["Sound/SoundCore"])
			ScspChangeSoundCore(newhash["Sound/SoundCore"].toInt());

		if (newhash["Video/WindowWidth"] != hash["Video/WindowWidth"] || newhash["Video/WindowHeight"] != hash["Video/WindowHeight"] ||
          newhash["View/Menubar"] != hash["View/Menubar"] || newhash["View/Toolbar"] != hash["View/Toolbar"] ||
			 newhash["Input/GunMouseSensitivity"] != hash["Input/GunMouseSensitivity"])
			sizeRequested(QSize(newhash["Video/WindowWidth"].toInt(),newhash["Video/WindowHeight"].toInt()));
		fixAspectRatio( rect().width() );

		if (newhash["Video/FullscreenWidth"] != hash["Video/FullscreenWidth"] ||
			newhash["Video/FullscreenHeight"] != hash["Video/FullscreenHeight"] ||
			newhash["Video/Fullscreen"] != hash["Video/Fullscreen"])
		{
			bool f = isFullScreen();
			if (f)
				fullscreenRequested( false );
			fullscreenRequested( f );
		}

		if (newhash["Video/VideoFormat"] != hash["Video/VideoFormat"])
			YabauseSetVideoFormat(newhash["Video/VideoFormat"].toInt());

		mYabauseThread->reloadControllers();
		refreshStatesActions();
	}
}

void UIYabause::on_aFileOpenISO_triggered()
{
	YabauseLocker locker( mYabauseThread );
	const QString fn = CommonDialogs::getOpenFileName( QtYabause::volatileSettings()->value( "Recents/ISOs" ).toString(), QtYabause::translate( "Select your iso/cue/bin file" ), QtYabause::translate( "CD Images (*.iso *.cue *.bin *.mds)" ) );
	if ( !fn.isEmpty() )
	{
		VolatileSettings* vs = QtYabause::volatileSettings();
		const int currentCDCore = vs->value( "General/CdRom" ).toInt();
		const QString currentCdRomISO = vs->value( "General/CdRomISO" ).toString();

		QtYabause::settings()->setValue( "Recents/ISOs", fn );

		vs->setValue( "autostart", false );
		vs->setValue( "General/CdRom", ISOCD.id );
		vs->setValue( "General/CdRomISO", fn );

		mYabauseThread->pauseEmulation( false, true );

		refreshStatesActions();
	}
}

void UIYabause::on_aFileOpenCDRom_triggered()
{
	YabauseLocker locker( mYabauseThread );
	QStringList list = getCdDriveList();
	int current = list.indexOf(QtYabause::volatileSettings()->value( "Recents/CDs").toString());
	QString fn = QInputDialog::getItem(this, QtYabause::translate("Open CD Rom"),
													QtYabause::translate("Choose a cdrom drive/mount point") + ":",
													list, current, false);
	if (!fn.isEmpty())
	{
		VolatileSettings* vs = QtYabause::volatileSettings();
		const int currentCDCore = vs->value( "General/CdRom" ).toInt();
		const QString currentCdRomISO = vs->value( "General/CdRomISO" ).toString();

		QtYabause::settings()->setValue( "Recents/CDs", fn );

		vs->setValue( "autostart", false );
		vs->setValue( "General/CdRom", QtYabause::defaultCDCore().id );
		vs->setValue( "General/CdRomISO", fn );

		mYabauseThread->pauseEmulation( false, true );

		refreshStatesActions();
	}
}

void UIYabause::on_mFileSaveState_triggered( QAction* a )
{
	if ( a == aFileSaveStateAs )
		return;
	YabauseLocker locker( mYabauseThread );
	if ( YabSaveStateSlot( QtYabause::volatileSettings()->value( "General/SaveStates", getDataDirPath() ).toString().toLatin1().constData(), a->data().toInt() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Couldn't save state file" ) );
	else
		refreshStatesActions();
}

void UIYabause::on_mFileLoadState_triggered( QAction* a )
{
	if ( a == aFileLoadStateAs )
		return;
	YabauseLocker locker( mYabauseThread );
	if ( YabLoadStateSlot( QtYabause::volatileSettings()->value( "General/SaveStates", getDataDirPath() ).toString().toLatin1().constData(), a->data().toInt() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Couldn't load state file" ) );
}

void UIYabause::on_aFileSaveStateAs_triggered()
{
	YabauseLocker locker( mYabauseThread );
	const QString fn = CommonDialogs::getSaveFileName( QtYabause::volatileSettings()->value( "General/SaveStates", getDataDirPath() ).toString(), QtYabause::translate( "Choose a file to save your state" ), QtYabause::translate( "Yabause Save State (*.yss)" ) );
	if ( fn.isNull() )
		return;
	if ( YabSaveState( fn.toLatin1().constData() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Couldn't save state file" ) );
}

void UIYabause::on_aFileLoadStateAs_triggered()
{
	YabauseLocker locker( mYabauseThread );
	const QString fn = CommonDialogs::getOpenFileName( QtYabause::volatileSettings()->value( "General/SaveStates", getDataDirPath() ).toString(), QtYabause::translate( "Select a file to load your state" ), QtYabause::translate( "Yabause Save State (*.yss)" ) );
	if ( fn.isNull() )
		return;
	if ( YabLoadState( fn.toLatin1().constData() ) != 0 )
		CommonDialogs::information( QtYabause::translate( "Couldn't load state file" ) );
	else
		aEmulationRun->trigger();
}

void UIYabause::on_aFileScreenshot_triggered()
{
	YabauseLocker locker( mYabauseThread );
	// images filter that qt can write
	QStringList filters;
	foreach ( QByteArray ba, QImageWriter::supportedImageFormats() )
		if ( !filters.contains( ba, Qt::CaseInsensitive ) )
			filters << QString( ba ).toLower();
	for ( int i = 0; i < filters.count(); i++ )
		filters[i] = QtYabause::translate( "%1 Images (*.%2)" ).arg( filters[i].toUpper() ).arg( filters[i] );

#if defined(HAVE_LIBGL) && !defined(QT_OPENGL_ES_1) && !defined(QT_OPENGL_ES_2)
	glReadBuffer(GL_FRONT);
#endif

	// take screenshot of gl view
	QImage screenshot = mYabauseGL->grabFrameBuffer();

	// request a file to save to to user
	QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for your screenshot" ), filters.join( ";;" ) );

	// if the user didn't provide a filename extension, we force it to png
	QFileInfo qfi( s );
	if ( qfi.suffix().isEmpty() )
		s += ".png";

	// write image if ok
	if ( !s.isEmpty() )
	{
		QImageWriter iw( s );
		if ( !iw.write( screenshot ))
		{
			CommonDialogs::information( QtYabause::translate( "An error occur while writing the screenshot: " + iw.errorString()) );
		}
	}
}

void UIYabause::on_aFileQuit_triggered()
{ close(); }

void UIYabause::on_aEmulationRun_triggered()
{
	if ( mYabauseThread->emulationPaused() )
	{
		mYabauseThread->pauseEmulation( false, false );
		refreshStatesActions();
		if (isFullScreen())
			hideMouseTimer->start(3 * 1000);
	}
}

void UIYabause::on_aEmulationPause_triggered()
{
	if ( !mYabauseThread->emulationPaused() )
		mYabauseThread->pauseEmulation( true, false );
}

void UIYabause::on_aEmulationReset_triggered()
{ mYabauseThread->resetEmulation(); }

void UIYabause::on_aEmulationFrameSkipLimiter_toggled( bool toggled )
{
	Settings* vs = QtYabause::settings();
	vs->setValue( "General/EnableFrameSkipLimiter", toggled );
	vs->sync();

	if ( toggled )
		EnableAutoFrameSkip();
	else
		DisableAutoFrameSkip();
}

void UIYabause::on_aToolsBackupManager_triggered()
{
	YabauseLocker locker( mYabauseThread );
	if ( mYabauseThread->init() < 0 )
	{
		CommonDialogs::information( QtYabause::translate( "Yabause is not initialized, can't manage backup ram." ) );
		return;
	}
	UIBackupRam( this ).exec();
}

void UIYabause::on_aToolsCheatsList_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UICheats( this ).exec();
}

void UIYabause::on_aToolsCheatSearch_triggered()
{
   YabauseLocker locker( mYabauseThread );
   UICheatSearch cs(this, &search, searchType);

   cs.exec();

   search = *cs.getSearchVariables( &searchType);
}

void UIYabause::on_aToolsTransfer_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIMemoryTransfer( mYabauseThread, this ).exec();
}

void UIYabause::on_aViewFPS_triggered( bool toggled )
{
	Settings* vs = QtYabause::settings();
	vs->setValue( "General/ShowFPS", toggled );
	vs->sync();
	SetOSDToggle(toggled ? 1 : 0);
}

void UIYabause::on_aViewLayerVdp1_triggered()
{ ToggleVDP1(); }

void UIYabause::on_aViewLayerNBG0_triggered()
{ ToggleNBG0(); }

void UIYabause::on_aViewLayerNBG1_triggered()
{ ToggleNBG1(); }

void UIYabause::on_aViewLayerNBG2_triggered()
{ ToggleNBG2(); }

void UIYabause::on_aViewLayerNBG3_triggered()
{ ToggleNBG3(); }

void UIYabause::on_aViewLayerRBG0_triggered()
{ ToggleRBG0(); }

void UIYabause::on_aViewFullscreen_triggered( bool b )
{
	fullscreenRequested( b );
	//ToggleFullScreen();
}

void UIYabause::breakpointHandlerMSH2(bool displayMessage)
{
	YabauseLocker locker( mYabauseThread );
	if (displayMessage)
		CommonDialogs::information( QtYabause::translate( "Breakpoint Reached" ) );
	UIDebugSH2( true, mYabauseThread, this ).exec();
}

void UIYabause::breakpointHandlerSSH2(bool displayMessage)
{
	YabauseLocker locker( mYabauseThread );
	if (displayMessage)
		CommonDialogs::information( QtYabause::translate( "Breakpoint Reached" ) );
	UIDebugSH2( false, mYabauseThread, this ).exec();
}

void UIYabause::breakpointHandlerM68K()
{
	YabauseLocker locker( mYabauseThread );
	CommonDialogs::information( QtYabause::translate( "Breakpoint Reached" ) );
	UIDebugM68K( mYabauseThread, this ).exec();
}

void UIYabause::breakpointHandlerSCUDSP()
{
	YabauseLocker locker( mYabauseThread );
	CommonDialogs::information( QtYabause::translate( "Breakpoint Reached" ) );
	UIDebugSCUDSP( mYabauseThread, this ).exec();
}

void UIYabause::breakpointHandlerSCSPDSP()
{
	YabauseLocker locker( mYabauseThread );
	CommonDialogs::information( QtYabause::translate( "Breakpoint Reached" ) );
	UIDebugSCSPDSP( mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugMSH2_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugSH2( true, mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugSSH2_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugSH2( false, mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugVDP1_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugVDP1( this ).exec();
}

void UIYabause::on_aViewDebugVDP2_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugVDP2( this ).exec();
}

void UIYabause::on_aViewDebugM68K_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugM68K( mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugSCUDSP_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugSCUDSP( mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugSCSP_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugSCSP( this ).exec();
}

void UIYabause::on_aViewDebugSCSPDSP_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIDebugSCSPDSP( mYabauseThread, this ).exec();
}

void UIYabause::on_aViewDebugMemoryEditor_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIMemoryEditor( mYabauseThread, this ).exec();
}

void UIYabause::on_aTraceLogging_triggered( bool toggled )
{
	SetInsTracingToggle(toggled? 1 : 0);
	return;
}

void UIYabause::on_aHelpCompatibilityList_triggered()
{ QDesktopServices::openUrl( QUrl( aHelpCompatibilityList->statusTip() ) ); }

void UIYabause::on_aHelpAbout_triggered()
{
	YabauseLocker locker( mYabauseThread );
	UIAbout( window() ).exec();
}

void UIYabause::on_aSound_triggered()
{
	// show volume widget
	sVolume->setValue(QtYabause::volatileSettings()->value( "Sound/Volume").toInt());
	QWidget* ab = toolBar->widgetForAction( aSound );
	fSound->move( ab->mapToGlobal( ab->rect().bottomLeft() ) );
	fSound->show();
}

void UIYabause::on_aVideoDriver_triggered()
{
	// set current core the selected one in the combo list
	if ( VIDCore )
	{
		cbVideoDriver->blockSignals( true );
		for ( int i = 0; VIDCoreList[i] != NULL; i++ )
		{
			if ( VIDCoreList[i]->id == VIDCore->id )
			{
				cbVideoDriver->setCurrentIndex( cbVideoDriver->findData( VIDCore->id ) );
				break;
			}
		}
		cbVideoDriver->blockSignals( false );
	}
	//  show video core widget
	QWidget* ab = toolBar->widgetForAction( aVideoDriver );
	fVideoDriver->move( ab->mapToGlobal( ab->rect().bottomLeft() ) );
	fVideoDriver->show();
}

void UIYabause::on_cbSound_toggled( bool toggled )
{
	if ( toggled )
		ScspUnMuteAudio(SCSP_MUTE_USER);
	else
		ScspMuteAudio(SCSP_MUTE_USER);
	cbSound->setIcon( QIcon( toggled ? ":/actions/sound.png" : ":/actions/mute.png" ) );
}

void UIYabause::on_sVolume_valueChanged( int value )
{
	ScspSetVolume( value );
	Settings* vs = QtYabause::settings();
	vs->setValue("Sound/Volume", value );
}

void UIYabause::on_cbVideoDriver_currentIndexChanged( int id )
{
	VideoInterface_struct* core = QtYabause::getVDICore( cbVideoDriver->itemData( id ).toInt() );
	if ( core )
	{
		if ( VideoChangeCore( core->id ) == 0 )
			mYabauseGL->updateView();
	}
}

void UIYabause::pause( bool paused )
{
	mYabauseGL->updateView();

	aEmulationRun->setEnabled( paused );
	aEmulationPause->setEnabled( !paused );
	aEmulationReset->setEnabled( !paused );
}

void UIYabause::reset()
{
	mYabauseGL->updateView();
}

void UIYabause::toggleEmulateMouse( bool enable )
{
	emulateMouse = enable;
}
