/* Stub for TextDrawer.h
 * Use to replace remove freetype library requirement.
 */

#include "TextDrawer.h"

TextDrawer g_textDrawer;

struct Atlas {
};

void TextDrawer::init()
{
}

void TextDrawer::destroy()
{
}

void TextDrawer::drawText(const char *_pText, float _x, float _y) const
{
}

void TextDrawer::getTextSize(const char *_pText, float & _w, float & _h) const
{
}

void TextDrawer::setTextColor(float * _color)
{
}
