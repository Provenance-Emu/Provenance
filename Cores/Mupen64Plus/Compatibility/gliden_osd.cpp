//
//  mupen_osd.cpp
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 4/13/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#include <stdio.h>

/* Stub for TextDrawer.h
 * Use to replace remove freetype library requirement.
 */

#include "TextDrawer.h"

#define EXPORT __attribute__((visibility("default")))


extern "C" {
	__attribute__((visibility("default")))
	void (*PV_OSD_Callback)(const char *_pText, float _x, float _y);

	EXPORT void SetOSDCallback(void (*inPV_OSD_Callback)(const char *_pText, float _x, float _y)) {
		PV_OSD_Callback = inPV_OSD_Callback;
	}

//	__attribute__((visibility("default")))
//	void _PV_ForceUpdateWindowSize(int width, int height)
//	{
//		windowSetting.uDisplayWidth = width;
//		windowSetting.uDisplayHeight = height;
//	}
}



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
	PV_OSD_Callback(_pText, _x, _y);
}

void TextDrawer::getTextSize(const char *_pText, float & _w, float & _h) const
{
}

void TextDrawer::setTextColor(float * _color)
{
}
