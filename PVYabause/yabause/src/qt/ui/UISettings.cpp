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
#include "UISettings.h"
#include "../Settings.h"
#include "../CommonDialogs.h"
#include "UIWaitInput.h"
#include "UIPortManager.h"

#include <QDir>
#include <QList>
#include <QDesktopWidget>

extern "C" {
extern M68K_struct* M68KCoreList[];
extern SH2Interface_struct* SH2CoreList[];
extern PerInterface_struct* PERCoreList[];
extern CDInterface* CDCoreList[];
extern SoundInterface_struct* SNDCoreList[];
extern VideoInterface_struct* VIDCoreList[];
extern OSD_struct* OSDCoreList[];
}

struct Item
{
	Item( const QString& i, const QString& n, bool e=true, bool s=true)
	{ id = i; Name = n; enableFlag = e; saveFlag = s; }
	
	QString id;
	QString Name;
	bool enableFlag;
	bool saveFlag;
};

typedef QList<Item> Items;

const Items mRegions = Items()
	<< Item( "Auto" , "Auto-detect" )
	<< Item( "J" , "Japan (NTSC)" )
	<< Item( "T", "Asia (NTSC)" )
	<< Item( "U", "North America (NTSC)" )
	<< Item( "B", "Central/South America (NTSC)" )
	<< Item( "K", "Korea (NTSC)" )
	<< Item( "A", "Asia (PAL)" )
	<< Item( "E", "Europe + others (PAL)" )
	<< Item( "L", "Central/South America (PAL)" );

const Items mCartridgeTypes = Items()
	<< Item( "0", "None", false, false )
	<< Item( "1", "Pro Action Replay", true, false )
	<< Item( "2", "4 Mbit Backup Ram", true, true )
	<< Item( "3", "8 Mbit Backup Ram", true, true )
	<< Item( "4", "16 Mbit Backup Ram", true, true )
	<< Item( "5", "32 Mbit Backup Ram", true, true )
	<< Item( "6", "8 Mbit Dram", false, false )
	<< Item( "7", "32 Mbit Dram", false, false )
	<< Item( "8", "Netlink", false, false )
	<< Item( "9", "16 Mbit ROM", true, false )
	<< Item( "10", "Japanese Modem", false, false );

const Items mVideoFormats = Items()
	<< Item( "0", "NTSC" )
	<< Item( "1", "PAL" );

UISettings::UISettings( QList <supportedRes_struct> *supportedResolutions, QList <translation_struct> *translations, QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

	QRect maxWinRect = QApplication::desktop()->availableGeometry();
	
	
	leWinWidth->setValidator(new QIntValidator(0, maxWinRect.width(), leWinWidth));
	leWinHeight->setValidator(new QIntValidator(0, maxWinRect.height(), leWinHeight));

	pmPort1->setPort( 1 );
	pmPort1->loadSettings();
	pmPort2->setPort( 2 );
	pmPort2->loadSettings();
	
	if ( p && !p->isFullScreen() )
	{
		setWindowFlags( Qt::Sheet );
	}

	setupCdDrives();

	// load cores informations
	loadCores();

	supportedRes = *supportedResolutions;
	loadSupportedResolutions();

#ifdef HAVE_LIBMINI18N
	trans = *translations;
	loadTranslations();
#else
   lTranslation->hide();
	cbTranslation->hide();
#endif

	loadShortcuts();

	// load settings
	loadSettings();
	
	// connections
	foreach ( QToolButton* tb, findChildren<QToolButton*>() )
	{
		connect( tb, SIGNAL( clicked() ), this, SLOT( tbBrowse_clicked() ) );
	}
	
	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

void UISettings::requestFile( const QString& c, QLineEdit* e, const QString& filters )
{
	const QString s = CommonDialogs::getOpenFileName( e->text(), c, filters );
	if ( !s.isNull() )
		e->setText( s );
}

void UISettings::requestNewFile( const QString& c, QLineEdit* e, const QString& filters )
{
	const QString s = CommonDialogs::getSaveFileName( e->text(), c, filters );
	if ( !s.isNull() )
		e->setText( s );
}

void UISettings::requestFolder( const QString& c, QLineEdit* e )
{
	const QString s = CommonDialogs::getExistingDirectory( e->text(), c );
	if ( !s.isNull() )
		e->setText( s );
}

QStringList getCdDriveList()
{
	QStringList list;

#if defined Q_OS_WIN
	foreach( QFileInfo drive, QDir::drives () )
	{
		LPCWSTR driveString = (LPCWSTR)drive.filePath().utf16();
		if (GetDriveTypeW(driveString) == DRIVE_CDROM)
			list.append(drive.filePath());
	}
#elif defined Q_OS_LINUX
	FILE * f = fopen("/proc/sys/dev/cdrom/info", "r");
	char buffer[1024];
	char drive_name[10];
	char drive_path[255];

	if (f != NULL) {
		while (fgets(buffer, 1024, f) != NULL) {
			if (sscanf(buffer, "drive name:%s", drive_name) == 1) {
				sprintf(drive_path, "/dev/%s", drive_name);

				list.append(drive_path);
			}
		}
	}
#elif defined Q_OS_MAC
#endif
	return list;
}

void UISettings::setupCdDrives()
{
	QStringList list=getCdDriveList();
	foreach(QString string, list)
		cbCdDrive->addItem(string);
}

void UISettings::tbBrowse_clicked()
{
	// get toolbutton sender
	QToolButton* tb = qobject_cast<QToolButton*>( sender() );
	
	if ( tb == tbBios )
		requestFile( QtYabause::translate( "Choose a bios file" ), leBios );
	else if ( tb == tbCdRom )
	{
		if ( cbCdRom->currentText().contains( "dummy", Qt::CaseInsensitive ) )
		{
			CommonDialogs::information( QtYabause::translate( "The dummies cores don't need configuration." ) );
			return;
		}
		else if ( cbCdRom->currentText().contains( "iso", Qt::CaseInsensitive ) )
			requestFile( QtYabause::translate( "Select your iso/cue/bin file" ), leCdRom, QtYabause::translate( "CD Images (*.iso *.cue *.bin *.mds)" ) );
		else
			requestFolder( QtYabause::translate( "Choose a cdrom drive/mount point" ), leCdRom );
	}
	else if ( tb == tbSaveStates )
		requestFolder( QtYabause::translate( "Choose a folder to store save states" ), leSaveStates );
	else if ( tb == tbCartridge )
	{
		if (mCartridgeTypes[cbCartridge->currentIndex()].saveFlag)
			requestNewFile( QtYabause::translate( "Choose a cartridge file" ), leCartridge );
		else
			requestFile( QtYabause::translate( "Choose a cartridge file" ), leCartridge );		    
	}
	else if ( tb == tbMemory )
		requestNewFile( QtYabause::translate( "Choose a memory file" ), leMemory );
	else if ( tb == tbMpegROM )
		requestFile( QtYabause::translate( "Choose a mpeg rom" ), leMpegROM );
}

void UISettings::on_cbInput_currentIndexChanged( int id )
{
	PerInterface_struct* core = QtYabause::getPERCore( cbInput->itemData( id ).toInt() );
        core->Init();
	
	Q_ASSERT( core );
	
	pmPort1->setCore( core );
	pmPort2->setCore( core );
}

void UISettings::on_cbCdRom_currentIndexChanged( int id )
{
	CDInterface* core = QtYabause::getCDCore( cbCdRom->itemData( id ).toInt() );

	Q_ASSERT( core );

	switch (core->id)
	{
		case CDCORE_DUMMY:
			cbCdDrive->setVisible(false);
			leCdRom->setVisible(false);
			tbCdRom->setVisible(false);
			break;
		case CDCORE_ISO:
			cbCdDrive->setVisible(false);
			leCdRom->setVisible(true);
			tbCdRom->setVisible(true);
			break;
		case CDCORE_ARCH:
			cbCdDrive->setVisible(true);
			leCdRom->setVisible(false);
			tbCdRom->setVisible(false);
			break;
		default: break;
	}
}

void UISettings::on_cbClockSync_stateChanged( int state )
{
	dteBaseTime->setVisible( state == Qt::Checked );
}

void UISettings::on_cbCartridge_currentIndexChanged( int id )
{
	leCartridge->setVisible(mCartridgeTypes[id].enableFlag);
	tbCartridge->setVisible(mCartridgeTypes[id].enableFlag);
}

void UISettings::loadCores()
{
	// CD Drivers
	for ( int i = 0; CDCoreList[i] != NULL; i++ )
		cbCdRom->addItem( QtYabause::translate( CDCoreList[i]->Name ), CDCoreList[i]->id );
	
	// VDI Drivers
	for ( int i = 0; VIDCoreList[i] != NULL; i++ )
		cbVideoCore->addItem( QtYabause::translate( VIDCoreList[i]->Name ), VIDCoreList[i]->id );

#if YAB_PORT_OSD
	// OSD Drivers
	for ( int i = 0; OSDCoreList[i] != NULL; i++ )
		cbOSDCore->addItem( QtYabause::translate( OSDCoreList[i]->Name ), OSDCoreList[i]->id );
#else
	delete cbOSDCore;
	delete lOSDCore;
#endif
	
	// Video Formats
	foreach ( const Item& it, mVideoFormats )
		cbVideoFormat->addItem( QtYabause::translate( it.Name ), it.id );
	
	// SND Drivers
	for ( int i = 0; SNDCoreList[i] != NULL; i++ )
		cbSoundCore->addItem( QtYabause::translate( SNDCoreList[i]->Name ), SNDCoreList[i]->id );
	
	// Cartridge Types
	foreach ( const Item& it, mCartridgeTypes )
		cbCartridge->addItem( QtYabause::translate( it.Name ), it.id );
	
	// Input Drivers
	for ( int i = 0; PERCoreList[i] != NULL; i++ )
		cbInput->addItem( QtYabause::translate( PERCoreList[i]->Name ), PERCoreList[i]->id );
	
	// Regions
	foreach ( const Item& it, mRegions )
		cbRegion->addItem( QtYabause::translate( it.Name ), it.id );
	
	// SH2 Interpreters
	for ( int i = 0; SH2CoreList[i] != NULL; i++ )
		cbSH2Interpreter->addItem( QtYabause::translate( SH2CoreList[i]->Name ), SH2CoreList[i]->id );
}

void UISettings::loadSupportedResolutions()
{
	if (supportedRes.count() == 0)
	{
		lFullScreenResolution->setVisible(false);
		cbFullscreenResolution->setVisible(false);
		return;
	}

	// Load supported screen resolutions
	for (int i = 0; i < this->supportedRes.count(); i++)
	{
		QString text = QString("%1x%2").arg(QString::number(this->supportedRes[i].width), 
			QString::number (this->supportedRes[i].height));
		if (cbFullscreenResolution->findText(text) != -1)
			continue;
		cbFullscreenResolution->addItem(text, i);
	}
}

void UISettings::loadTranslations()
{
	cbTranslation->addItem(QString::fromUtf8(_("Use System Locale")), "");
	cbTranslation->addItem("English", "#");
	for (int i = 0; i < this->trans.count(); i++)
		cbTranslation->addItem(trans[i].name.left(1).toUpper()+trans[i].name.mid(1), trans[i].file);

}

void UISettings::loadShortcuts()
{	
	QList<QAction *> actions = parent()->findChildren<QAction *>();
	foreach ( QAction* action, actions )
	{
		if (action->text().isEmpty())
			continue;

		actionsList.append(action);
	}

	int row=0;
	twShortcuts->setRowCount(actionsList.count());
	foreach ( QAction* action, actionsList )
	{
		QTableWidgetItem *tblItem = new QTableWidgetItem(QString::fromUtf8(_(action->text().toUtf8())));
		tblItem->setFlags(tblItem->flags() ^ Qt::ItemIsEditable);
		twShortcuts->setItem(row, 0, tblItem);
		tblItem = new QTableWidgetItem(action->shortcut().toString());
		twShortcuts->setItem(row, 1, tblItem);
		row++;
	}
	QHeaderView *headerView = twShortcuts->horizontalHeader();
#if QT_VERSION >= 0x04FF00
	headerView->setSectionResizeMode(QHeaderView::Stretch);
	headerView->setSectionResizeMode(1, QHeaderView::Interactive);
#else
	headerView->setResizeMode(QHeaderView::Stretch);
	headerView->setResizeMode(1, QHeaderView::Interactive);
#endif
}

void UISettings::applyShortcuts()
{
	for (int row = 0; row < (int)actionsList.size(); ++row) 
	{
		QAction *action = actionsList[row];
		action->setShortcut(QKeySequence(twShortcuts->item(row, 1)->text()));
	}
}

void UISettings::loadSettings()
{
	// get settings pointer
	Settings* s = QtYabause::settings();

	// general
	leBios->setText( s->value( "General/Bios" ).toString() );
	cbCdRom->setCurrentIndex( cbCdRom->findData( s->value( "General/CdRom", QtYabause::defaultCDCore().id ).toInt() ) );
	leCdRom->setText( s->value( "General/CdRomISO" ).toString() );
	if (s->value( "General/CdRom", QtYabause::defaultCDCore().id ).toInt() == CDCORE_ARCH)
		cbCdDrive->setCurrentIndex(leCdRom->text().isEmpty() ? 0 : cbCdDrive->findText(leCdRom->text()));

	leSaveStates->setText( s->value( "General/SaveStates", getDataDirPath() ).toString() );
#ifdef HAVE_LIBMINI18N
	int i;
	if ((i=cbTranslation->findData(s->value( "General/Translation" ).toString())) != -1)
		cbTranslation->setCurrentIndex(i);
	else
		cbTranslation->setCurrentIndex(0);
#endif
	cbEnableFrameSkipLimiter->setChecked( s->value( "General/EnableFrameSkipLimiter" ).toBool() );
	cbShowFPS->setChecked( s->value( "General/ShowFPS" ).toBool() );
	cbAutostart->setChecked( s->value( "autostart" ).toBool() );

	bool clocksync = s->value( "General/ClockSync" ).toBool();
	cbClockSync->setChecked( clocksync );	 
	dteBaseTime->setVisible( clocksync );

	QString dt = s->value( "General/FixedBaseTime" ).toString();
	if (!dt.isEmpty())		
		dteBaseTime->setDateTime( QDateTime::fromString( dt,Qt::ISODate) );
	else
		dteBaseTime->setDateTime( QDateTime(QDate(1998, 1, 1), QTime(12, 0, 0)) );

	// video
	cbVideoCore->setCurrentIndex( cbVideoCore->findData( s->value( "Video/VideoCore", QtYabause::defaultVIDCore().id ).toInt() ) );
#if YAB_PORT_OSD
	cbOSDCore->setCurrentIndex( cbOSDCore->findData( s->value( "Video/OSDCore", QtYabause::defaultOSDCore().id ).toInt() ) );
#endif

	leWinWidth->setText( s->value( "Video/WindowWidth", s->value( "Video/Width", 640 ) ).toString() );
	leWinHeight->setText( s->value( "Video/WindowHeight", s->value( "Video/Height", 480 ) ).toString() );
	QString text = QString("%1x%2").arg(s->value( "Video/FullscreenWidth", s->value( "Video/Width", 640 ) ).toString(),
										s->value( "Video/FullscreenHeight", s->value( "Video/Height", 480 ) ).toString());	
	cbFullscreenResolution->setCurrentIndex(cbFullscreenResolution->findText(text));
	cbFullscreen->setChecked( s->value( "Video/Fullscreen", false ).toBool() );
	cbVideoFormat->setCurrentIndex( cbVideoFormat->findData( s->value( "Video/VideoFormat", mVideoFormats.at( 0 ).id ).toInt() ) );

	// sound
	cbSoundCore->setCurrentIndex( cbSoundCore->findData( s->value( "Sound/SoundCore", QtYabause::defaultSNDCore().id ).toInt() ) );

	// cartridge/memory
	cbCartridge->setCurrentIndex( cbCartridge->findData( s->value( "Cartridge/Type", mCartridgeTypes.at( 0 ).id ).toInt() ) );
	leCartridge->setText( s->value( "Cartridge/Path" ).toString() );
	leMemory->setText( s->value( "Memory/Path", getDataDirPath().append( "/bkram.bin" ) ).toString() );
	leMpegROM->setText( s->value( "MpegROM/Path" ).toString() );
	
	// input
	cbInput->setCurrentIndex( cbInput->findData( s->value( "Input/PerCore", QtYabause::defaultPERCore().id ).toInt() ) );
	sGunMouseSensitivity->setValue(s->value( "Input/GunMouseSensitivity", 100).toInt() );
	
	// advanced
	cbRegion->setCurrentIndex( cbRegion->findData( s->value( "Advanced/Region", mRegions.at( 0 ).id ).toString() ) );
	cbSH2Interpreter->setCurrentIndex( cbSH2Interpreter->findData( s->value( "Advanced/SH2Interpreter", QtYabause::defaultSH2Core().id ).toInt() ) );

	// view
	bgShowMenubar->setId( rbMenubarNever, BD_NEVERHIDE );
	bgShowMenubar->setId( rbMenubarFullscreen, BD_HIDEFS );
	bgShowMenubar->setId( rbMenubarAlways, BD_ALWAYSHIDE );
	bgShowMenubar->setId( rbMenubarFullscreenHover, BD_SHOWONFSHOVER );
	bgShowMenubar->button( s->value( "View/Menubar", BD_SHOWONFSHOVER ).toInt() )->setChecked( true );

	bgShowToolbar->setId( rbToolbarNever, BD_NEVERHIDE );
	bgShowToolbar->setId( rbToolbarFullscreen, BD_HIDEFS );
	bgShowToolbar->setId( rbToolbarAlways, BD_ALWAYSHIDE );
	bgShowToolbar->button( s->value( "View/Toolbar", BD_HIDEFS ).toInt() )->setChecked( true );

	bgShowLogWindow->setId( rbLogWindowNever, 0 );
	bgShowLogWindow->setId( rbLogWindowMessage, 1 );
	bgShowLogWindow->button( s->value( "View/LogWindow", 0 ).toInt() )->setChecked( true );
}

void UISettings::saveSettings()
{
	// get settings pointer
	Settings* s = QtYabause::settings();

	// general
	s->setValue( "General/Bios", leBios->text() );
	s->setValue( "General/CdRom", cbCdRom->itemData( cbCdRom->currentIndex() ).toInt() );
	CDInterface* core = QtYabause::getCDCore( cbCdRom->itemData( cbCdRom->currentIndex() ).toInt() );
	if ( core->id == CDCORE_ARCH )
		s->setValue( "General/CdRomISO", cbCdDrive->currentText() );
	else
		s->setValue( "General/CdRomISO", leCdRom->text() );
	s->setValue( "General/SaveStates", leSaveStates->text() );
#ifdef HAVE_LIBMINI18N
	s->setValue( "General/Translation", cbTranslation->itemData(cbTranslation->currentIndex()).toString() );
#endif
	s->setValue( "General/EnableFrameSkipLimiter", cbEnableFrameSkipLimiter->isChecked() );
	s->setValue( "General/ShowFPS", cbShowFPS->isChecked() );
	s->setValue( "autostart", cbAutostart->isChecked() );

	// video
	s->setValue( "Video/VideoCore", cbVideoCore->itemData( cbVideoCore->currentIndex() ).toInt() );
#if YAB_PORT_OSD
	s->setValue( "Video/OSDCore", cbOSDCore->itemData( cbOSDCore->currentIndex() ).toInt() );
#endif
	// Move Outdated window/fullscreen keys
	s->remove("Video/Width");
	s->remove("Video/Height");

	// Save new version of keys
	s->setValue( "Video/WindowWidth", leWinWidth->text() );
	s->setValue( "Video/WindowHeight", leWinHeight->text() );

	if (supportedRes.count() > 0)
	{
		supportedRes_struct res = supportedRes[cbFullscreenResolution->itemData(cbFullscreenResolution->currentIndex()).toInt()];
		s->setValue( "Video/FullscreenWidth", res.width );
		s->setValue( "Video/FullscreenHeight", res.height );
	}

	s->setValue( "Video/Fullscreen", cbFullscreen->isChecked() );
	s->setValue( "Video/VideoFormat", cbVideoFormat->itemData( cbVideoFormat->currentIndex() ).toInt() );

	s->setValue( "General/ClockSync", cbClockSync->isChecked() );
	s->setValue( "General/FixedBaseTime", dteBaseTime->dateTime().toString(Qt::ISODate));

	// sound
	s->setValue( "Sound/SoundCore", cbSoundCore->itemData( cbSoundCore->currentIndex() ).toInt() );

	// cartridge/memory
	s->setValue( "Cartridge/Type", cbCartridge->itemData( cbCartridge->currentIndex() ).toInt() );
	s->setValue( "Cartridge/Path", leCartridge->text() );
	s->setValue( "Memory/Path", leMemory->text() );
	s->setValue( "MpegROM/Path", leMpegROM->text() );
	
	// input
	s->setValue( "Input/PerCore", cbInput->itemData( cbInput->currentIndex() ).toInt() );	
	s->setValue( "Input/GunMouseSensitivity", sGunMouseSensitivity->value() );
	
	// advanced
	s->setValue( "Advanced/Region", cbRegion->itemData( cbRegion->currentIndex() ).toString() );
	s->setValue( "Advanced/SH2Interpreter", cbSH2Interpreter->itemData( cbSH2Interpreter->currentIndex() ).toInt() );

	// view
	s->setValue( "View/Menubar", bgShowMenubar->checkedId() );
	s->setValue( "View/Toolbar", bgShowToolbar->checkedId() );
	s->setValue( "View/LogWindow", bgShowLogWindow->checkedId() );

	// shortcuts
	applyShortcuts();
	s->beginGroup("Shortcuts");
	QList<QAction *> actions = parent()->findChildren<QAction *>();
	foreach ( QAction* action, actions )
	{
		if (action->text().isEmpty())
			continue;

		QString accelText = QString(action->shortcut().toString());
		s->setValue(action->text(), accelText);
	}
	s->endGroup();
}

void UISettings::accept()
{
	saveSettings();
	QDialog::accept();
}
