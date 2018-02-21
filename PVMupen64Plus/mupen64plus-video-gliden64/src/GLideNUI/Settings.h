#ifndef SETTINGS_H
#define SETTINGS_H

void loadSettings(const QString & _strIniFolder);
void writeSettings(const QString & _strIniFolder);
void loadCustomRomSettings(const QString & _strIniFolder, const char * _strRomName);
QString getTranslationFile();

#endif // SETTINGS_H

