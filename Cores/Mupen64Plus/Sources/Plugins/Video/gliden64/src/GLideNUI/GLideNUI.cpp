#include <thread>
#include <QApplication>
#include <QTranslator>

#include "GLideNUI.h"
#include "AboutDialog.h"
#include "ConfigDialog.h"
#include "Settings.h"
#include "../Config.h"

#ifdef QT_STATICPLUGIN
#include <QtPlugin>
Q_IMPORT_PLUGIN(QWindowsIntegrationPlugin)
Q_IMPORT_PLUGIN(QICOPlugin)
#endif

//#define RUN_DIALOG_IN_THREAD

inline void initMyResource() { Q_INIT_RESOURCE(icon); }
inline void cleanMyResource() { Q_CLEANUP_RESOURCE(icon); }

static
int openConfigDialog(const wchar_t * _strFileName, const char * _romName, bool & _accepted)
{
	cleanMyResource();
	initMyResource();
	QString strIniFileName = QString::fromWCharArray(_strFileName);
	loadSettings(strIniFileName);
	if (config.generalEmulation.enableCustomSettings != 0 && _romName != nullptr && strlen(_romName) != 0)
		loadCustomRomSettings(strIniFileName, _romName);

	int argc = 0;
	char * argv = 0;
	QApplication a(argc, &argv);

	QTranslator translator;
	if (translator.load(getTranslationFile(), strIniFileName))
		a.installTranslator(&translator);

	ConfigDialog w(Q_NULLPTR, Qt::WindowTitleHint | Qt::WindowSystemMenuHint | Qt::WindowCloseButtonHint);

	w.setIniPath(strIniFileName);
	w.setRomName(_romName);
	w.setTitle();
	w.show();
	const int res = a.exec();
	_accepted = w.isAccepted();
	return res;
}

static
int openAboutDialog(const wchar_t * _strFileName)
{
	cleanMyResource();
	initMyResource();

	int argc = 0;
	char * argv = 0;
	QApplication a(argc, &argv);

	QTranslator translator;
	if (translator.load(getTranslationFile(), QString::fromWCharArray(_strFileName)))
		a.installTranslator(&translator);

	AboutDialog w(Q_NULLPTR, Qt::WindowTitleHint | Qt::WindowSystemMenuHint | Qt::WindowCloseButtonHint);
	w.show();
	return a.exec();
}

bool runConfigThread(const wchar_t * _strFileName, const char * _romName) {
	bool accepted = false;
#ifdef RUN_DIALOG_IN_THREAD
	std::thread configThread(openConfigDialog, _strFileName, std::ref(accepted));
	configThread.join();
#else
	openConfigDialog(_strFileName, _romName, accepted);
#endif
	return accepted;

}

int runAboutThread(const wchar_t * _strFileName) {
#ifdef RUN_DIALOG_IN_THREAD
	std::thread aboutThread(openAboutDialog, _strFileName);
	aboutThread.join();
#else
	openAboutDialog(_strFileName);
#endif
	return 0;
}

EXPORT bool CALL RunConfig(const wchar_t * _strFileName, const char * _romName)
{
	return runConfigThread(_strFileName, _romName);
}

EXPORT int CALL RunAbout(const wchar_t * _strFileName)
{
	return runAboutThread(_strFileName);
}

EXPORT void CALL LoadConfig(const wchar_t * _strFileName)
{
	loadSettings(QString::fromWCharArray(_strFileName));
}

EXPORT void CALL LoadCustomRomSettings(const wchar_t * _strFileName, const char * _romName)
{
	loadCustomRomSettings(QString::fromWCharArray(_strFileName), _romName);
}
