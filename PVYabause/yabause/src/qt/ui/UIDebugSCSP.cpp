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
#include "UIDebugSCSP.h"
#include "CommonDialogs.h"

#include <QImageWriter>
#include <QGraphicsPixmapItem>
#include <QDebug>
#include <QIODevice>
#include <QTimer>

UIDebugSCSP::UIDebugSCSP( QWidget* p )
	: QDialog( p )
{
	// setup dialog
	setupUi( this );

   sbSlotNumber->setMinimum(0);
   sbSlotNumber->setMaximum(31);
   sbSlotNumber->setValue(31);
   sbSlotNumber->setValue(0);

   // Setup Common Control registers
   if (HighWram)
   {
      char tempstr[2048];
      ScspCommonControlRegisterDebugStats(tempstr);
      pteCommonControlRegisters->appendPlainText(tempstr);
      pteCommonControlRegisters->moveCursor(QTextCursor::Start);
   }

#ifdef HAVE_QT_MULTIMEDIA
	audioBufferTimer = new QTimer(this);
	audioDeviceInfo = QAudioDeviceInfo::defaultOutputDevice();
	audioOutput = 0;
	slot_workbuf = 0;
	slot_buf = 0;
	initAudio();
#endif

   // Disable DSP Register display
   gbDSPControlRegisters->setVisible( false );

	// retranslate widgets
	QtYabause::retranslateWidget( this );
}

UIDebugSCSP::~UIDebugSCSP()
{
#ifdef HAVE_QT_MULTIMEDIA
	delete slot_workbuf;
	delete slot_buf;
#endif
}

#ifdef HAVE_QT_MULTIMEDIA
void UIDebugSCSP::initAudio()
{
	connect(audioBufferTimer, SIGNAL(timeout()), SLOT(audioBufferRefill()));

	isPlaying = true;

#if QT_VERSION < 0x040700
	audioFormat.setFrequency(44100);
	audioFormat.setChannels(2);
#else
	audioFormat.setSampleRate(44100);
	audioFormat.setChannelCount(2);
#endif
	audioFormat.setSampleSize(16);
	audioFormat.setCodec("audio/pcm");
	audioFormat.setByteOrder(QAudioFormat::LittleEndian);
	audioFormat.setSampleType(QAudioFormat::SignedInt);

	QAudioDeviceInfo info(QAudioDeviceInfo::defaultOutputDevice());
	if (!info.isFormatSupported(audioFormat)) 
	{
		qWarning() << "Normal format not available, trying alternative";
		audioFormat = info.nearestFormat(audioFormat);
	}

	delete audioOutput;
	audioOutput = 0;
	audioOutput = new QAudioOutput(audioDeviceInfo, audioFormat, this);
	connect(audioOutput, SIGNAL(notify()), SLOT(notified()));
	connect(audioOutput, SIGNAL(stateChanged(QAudio::State)), SLOT(stateChanged(QAudio::State)));

	ScspSlotResetDebug(sbSlotNumber->value());
}

void UIDebugSCSP::notified()
{
	qWarning() << "bytesFree = " << audioOutput->bytesFree()
		<< ", " << "elapsedUSecs = " << audioOutput->elapsedUSecs()
		<< ", " << "processedUSecs = " << audioOutput->processedUSecs()
		<< ", " << "periodSize = " << audioOutput->periodSize();
}

void UIDebugSCSP::audioBufferRefill()
{
	if (audioOutput && audioOutput->state() != QAudio::StoppedState) 
	{
		int chunks = audioOutput->bytesFree()/audioOutput->periodSize();
		while (chunks) 
		{
			int len=audioOutput->periodSize();
			len = (len/2) + (len%2);
			if (ScspSlotDebugAudio (slot_workbuf, slot_buf, len) == 0)
				break;
			outputDevice->write((char *)slot_buf, audioOutput->periodSize());
			--chunks;
		}
	}
}

void UIDebugSCSP::stateChanged(QAudio::State state)
{
	if (state == QAudio::IdleState)
	{
		delete slot_workbuf;
		delete slot_buf;
		slot_workbuf = 0;
		slot_buf = 0;
		notified();
		slot_workbuf = new u32[audioOutput->periodSize()*4];
		slot_buf = new s16[audioOutput->periodSize()];
	}
}
#endif

void UIDebugSCSP::on_sbSlotNumber_valueChanged ( int i )
{
   // Update Sound Slot Info
   char tempstr[2048];
   if (HighWram)
   {
      ScspSlotDebugStats(i, tempstr);
      pteSlotInfo->clear();
      pteSlotInfo->appendPlainText(tempstr);
      pteSlotInfo->moveCursor(QTextCursor::Start);
      pbSaveAsWav->setEnabled(true);
      pbSaveSlotRegisters->setEnabled(true);
   }
   else
   {
      pbSaveAsWav->setEnabled(false);
      pbSaveSlotRegisters->setEnabled(false);
   }
}

#ifdef HAVE_QT_MULTIMEDIA
void UIDebugSCSP::on_pbPlaySlot_clicked ()
{
	audioBufferTimer->stop();
	audioOutput->stop();

	if (isPlaying) 
	{
		ScspSlotResetDebug(sbSlotNumber->value());
		pbPlaySlot->setText(QtYabause::translate("Stop Slot"));
		outputDevice = audioOutput->start();
		isPlaying = false;
		audioBufferTimer->start(20);
	} 
	else 
	{
		pbPlaySlot->setText(QtYabause::translate("Play Slot"));
		isPlaying = true;
	}
}
#endif

void UIDebugSCSP::on_pbSaveAsWav_clicked ()
{
	// request a file to save to to user
   QString text;
   
   text.sprintf("channel%02d.wav", sbSlotNumber->value());
	const QString s = CommonDialogs::getSaveFileName(text, QtYabause::translate( "Choose a location for your wav file" ), QtYabause::translate( "WAV Files (*.wav)" ) );
	
	// write image if ok
	if ( !s.isEmpty() )
		if (ScspSlotDebugAudioSaveWav(sbSlotNumber->value(), s.toLatin1()) != 0)
			CommonDialogs::information( QtYabause::translate( "An error occured while writing file." ) );                  
}

void UIDebugSCSP::on_pbSaveSlotRegisters_clicked ()
{
	const QString s = CommonDialogs::getSaveFileName( QString(), QtYabause::translate( "Choose a location for your binary file" ), QtYabause::translate( "Binary Files (*.bin)" ) );
	if ( !s.isEmpty() )
      if (ScspSlotDebugSaveRegisters(sbSlotNumber->value(), s.toLatin1()) != 0)
			CommonDialogs::information( QtYabause::translate( "An error occured while writing file." ) );
}
