#pragma once

/*  This file is part of Imagine.

	Imagine is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	Imagine is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Imagine.  If not, see <http://www.gnu.org/licenses/> */

#include "gralloc.h"

// Wrapper for ANativeWindowBuffer (android_native_buffer_t)
// similar to GraphicBuffer class in Android frameworks

namespace opengl
{

class GraphicBuffer : public android_native_buffer_t
{
public:
	GraphicBuffer();
	~GraphicBuffer();
	bool reallocate(unsigned int w, unsigned int h, unsigned int format, unsigned int usage);
	bool lock(unsigned int usage, void **vaddr);
	bool lock(unsigned int _usage, int _x0, int _y0, int _width, int _height, void **_vaddr);
	void unlock();
	unsigned int getWidth();
	unsigned int getHeight();
	unsigned int getStride();
	android_native_buffer_t *getNativeBuffer();
	static bool hasBufferMapper();

private:
	bool initSize(unsigned int w, unsigned int h, unsigned int format, unsigned int usage);
};

}
