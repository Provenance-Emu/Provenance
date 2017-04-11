#ifndef VOLATILESETTINGS_H
#define VOLATILESETTINGS_H

#include <QObject>
#include <QString>
#include <QVariant>
#include <QHash>

class VolatileSettings : public QObject
{
	Q_OBJECT
	
protected:
	QHash<QString, QVariant> mValues;

public:
	void clear();
	void setValue(const QString & key, const QVariant & value);
	void removeValue(const QString& key);
	QVariant value(const QString & key, const QVariant & defaultValue = QVariant()) const;
};

#endif
