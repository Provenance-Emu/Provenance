#include "VolatileSettings.h"
#include "Settings.h"
#include "QtYabause.h"

void VolatileSettings::clear()
{
	mValues.clear();
}

void VolatileSettings::setValue(const QString & key, const QVariant & value)
{
	mValues[key] = value;
}

void VolatileSettings::removeValue(const QString & key)
{
	mValues.remove(key);
}

QVariant VolatileSettings::value(const QString & key, const QVariant & defaultValue) const
{
	if (mValues.contains(key))
		return mValues[key];

	Settings * s = QtYabause::settings();
	return s->value(key, defaultValue);
}
