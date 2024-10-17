#-------------------------------------------------
#
# Project created by QtCreator 2015-01-26T21:59:49
#
#-------------------------------------------------

QT       += core gui
QTPLUGIN += qico

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = GLideNUI
TEMPLATE = lib
CONFIG += staticlib
CONFIG += c++11

VPATH += ./../../src/GLideNUI/
SOURCES += \
	ConfigDialog.cpp \
	GLideNUI.cpp \
	FullscreenResolutions_windows.cpp \
	Settings.cpp \
	ScreenShot.cpp \
	AboutDialog.cpp

HEADERS += \
	ConfigDialog.h \
	GLideNUI.h \
	FullscreenResolutions.h \
	Settings.h \
	AboutDialog.h

RESOURCES += \
	icon.qrc

FORMS += \
	configDialog.ui \
	AboutDialog.ui

TRANSLATIONS = gliden64_fr.ts \
               gliden64_de.ts \
               gliden64_it.ts \
               gliden64_es.ts \
               gliden64_pl.ts \
               gliden64_pt_BR.ts \
               gliden64_ja.ts

DISTFILES +=
