#include "Arguments.h"
#include "VolatileSettings.h"
#include "QtYabause.h"

#include <iostream>
#include <iomanip>

#include <QApplication>
#include <QString>
#include <QStringList>
#include <QStringListIterator>
#include <QVector>
#include <QVectorIterator>

#include <stdlib.h>
#include <stdio.h>

namespace Arguments
{

	void autoframeskip(const QString& param);
	void autoload(const QString& param);
	void autostart(const QString& param);
	void binary(const QString& param);
	void bios(const QString& param);
	void cdrom(const QString& param);
	void fullscreen(const QString& param);
	void help(const QString& param);
	void iso(const QString& param);
	void nobios(const QString& param);
	void nosound(const QString& param);
	void version(const QString& param);

	struct Option
	{
		const char * shortname;
		const char * longname;
		const char * parameter;
		const char * description;
		unsigned short priority;
		void (*callback)(const QString& param);
	};

	static Option LAST_OPTION = { NULL, NULL, NULL, NULL, 0 };

	static Option availableOptions[] =
	{
		{ NULL,  "--autoframeskip=", "0|1", "Enable or disable auto frame skipping / limiting.",  2, autoframeskip },
		{ NULL,  "--autoload=", "<SAVESTATE>", "Automatically start emulation and load a save state.",1, autoload },
		{ "-a",  "--autostart", NULL,       "Automatically start emulation.",                      1, autostart },
		{ NULL,  "--binary=", "<FILE>[:ADDRESS]", "Use a binary file.",                           1, binary },
		{ "-b",  "--bios=", "<BIOS>",       "Choose a bios file.",                                3, bios },
		{ "-c",  "--cdrom=", "<CDROM>",     "Choose the cdrom device.",                           4, cdrom },
		{ "-f",  "--fullscreen", NULL,      "Start the emulator in fullscreen.",                  5, fullscreen },
		{ "-h",  "--help", NULL,            "Show this help and exit.",                           0, help },
		{ "-i",  "--iso=", "<ISO>",         "Choose a dump file.",                                4, iso },
                { "-nb", "--no-bios", NULL,         "Use the emulated bios",                              3, nobios },
                { "-ns", "--no-sound", NULL,        "Turns sound off.",                                   6, nosound },
		{ "-v",  "--version", NULL,         "Show version and exit.",                             0, version },
		LAST_OPTION
	};

	void parse()
	{
		QVector<Option *> choosenOptions(7);
		QVector<QString> params(7);

		QStringList arguments = QApplication::arguments();
		QStringListIterator argit(arguments);
		
		while(argit.hasNext())
		{
			QString argument = argit.next();
			Option * option = & * availableOptions;
			while(option->longname)
			{
				if (argument == option->shortname)
				{
					choosenOptions[option->priority] = option;
					if (option->parameter)
						params[option->priority] = argit.next();
				}
				if (argument.startsWith(option->longname))
				{
					choosenOptions[option->priority] = option;
					if (option->parameter)
						params[option->priority] = argument.mid(strlen(option->longname));
				}
				option++;
			}
		}
		
		for(int i = 0;i < 7;i++)
		{
			Option * option = choosenOptions[i];
			if (option)
				if (option->parameter)
					option->callback(params[i]);
				else
					option->callback(QString());
		}
	}

	void autoframeskip(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("General/EnableFrameSkipLimiter", param);
	}

	void autoload(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("autostart", true);
		vs->setValue("autostart/load", true);
		vs->setValue("autostart/load/slot", param.toInt());
	}

	void autostart(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("autostart", true);
	}

	void binary(const QString& param)
	{
		QString filename;
		uint address = 0x06004000;
		QStringList parts = param.split(':');
		filename = parts[0];
		if (parts.size() > 1)
			address = parts[1].toUInt(NULL, 0);

		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("autostart", true);
		vs->setValue("autostart/binary", true);
		vs->setValue("autostart/binary/filename", filename);
		vs->setValue("autostart/binary/address", address);
	}

	void bios(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("General/Bios", param);
	}

	void cdrom(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("General/CdRom", CDCORE_ARCH);
		vs->setValue("General/CdRomISO", param);
	}

	void fullscreen(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("Video/Fullscreen", true);
	}

	void help(const QString& param)
	{
		std::cout << "Yabause:" << std::endl;
		
		Option * option = & * availableOptions;
		while(option->longname)
		{
			QString longandparam(option->longname);
			if (option->parameter)
				longandparam.append(option->parameter);

			if (option->shortname)
				std::cout << std::setw(5) << std::right << option->shortname << ", ";
			else
				std::cout << std::setw(7) << ' ';
			std::cout << std::setw(27) << std::left << longandparam.toLocal8Bit().constData()
				<< option->description
				<< std::endl;
			option++;
		}
		
		exit(0);
	}

	void iso(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue( "General/CdRom", CDCORE_ISO );
		vs->setValue( "General/CdRomISO", param );
	}

	void nobios(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("General/Bios", "");
	}

	void nosound(const QString& param)
	{
		VolatileSettings * vs = QtYabause::volatileSettings();
		vs->setValue("Sound/SoundCore", SNDCORE_DUMMY);
	}

	void version(const QString& param)
	{
		std::cout << VERSION << std::endl;
		
		exit(0);
	}

}
