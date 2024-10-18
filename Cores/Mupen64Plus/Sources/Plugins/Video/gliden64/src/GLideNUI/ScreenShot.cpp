#include <QDir>
#include <QFile>
#include <QImage>
#include <QImageWriter>
#include "GLideNUI.h"

#include "../Config.h"

EXPORT void CALL SaveScreenshot(const wchar_t * _folder, const char * _name, int _width, int _height, const unsigned char * _data)
{
	const char * png = "png";
	const char * jpg = "jpg";
	const char * fileExt = config.texture.screenShotFormat == 0 ? png : jpg;
	QString folderName = QString::fromWCharArray(_folder);
	QDir folder;
	if (!folder.exists(folderName) && !folder.mkpath(folderName))
		return;

	QString romName(_name);
	romName = romName.replace(' ', '_');
	romName = romName.replace(':', ';');
	QString fileName;
	int i;
	for (i = 0; i < 1000; ++i) {
		fileName = fileName.sprintf("%lsGLideN64_%ls_%03i.%s", folderName.data(), romName.data(), i, fileExt);
		QFile f(fileName);
		if (!f.exists())
			break;
	}
	if (i == 1000)
		return;
	QImage image(_data, _width, _height, QImage::Format_RGB888);
	QImageWriter writer(fileName, fileExt);
	writer.write(image.mirrored());
}
