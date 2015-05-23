//
//   Copyright (C) 2008 by sinamas <sinamas at users.sourceforge.net>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License version 2 for more details.
//
//   You should have received a copy of the GNU General Public License
//   version 2 along with this program; if not, write to the
//   Free Software Foundation, Inc.,
//   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#include "state_osd_elements.h"
#include "array.h"
#include "bitmap_font.h"
#include "statesaver.h"
#include <fstream>
#include <cstring>

namespace {

using namespace gambatte;

namespace text {
using namespace bitmapfont;
static const char stateLoaded[] = { S,t,a,t,e,SPC,N0,SPC,l,o,a,d,e,d,0 };
static const char stateSaved[]  = { S,t,a,t,e,SPC,N0,SPC,s,a,v,e,d,0 };
static const std::size_t stateLoadedWidth = getWidth(stateLoaded);
static const std::size_t stateSavedWidth  = getWidth(stateSaved);
}

class ShadedTextOsdElment : public OsdElement {
	struct ShadeFill {
		void operator()(uint_least32_t *dest, const std::ptrdiff_t pitch) const {
			dest[2] = dest[1] = dest[0] = 0x000000ul;
			dest += pitch;
			dest[2] = dest[0] = 0x000000ul;
			dest += pitch;
			dest[2] = dest[1] = dest[0] = 0x000000ul;
		}
	};

	Array<uint_least32_t> const pixels;
	unsigned life;
public:
	ShadedTextOsdElment(unsigned w, const char *txt);
	const uint_least32_t* update();
};

ShadedTextOsdElment::ShadedTextOsdElment(unsigned width, const char *txt)
: OsdElement(bitmapfont::MAX_WIDTH, 144 - bitmapfont::HEIGHT * 2,
             width + 2, bitmapfont::HEIGHT + 2, three_fourths)
, pixels(std::size_t(w()) * h())
, life(4 * 60)
{
	std::memset(pixels, 0xFF, pixels.size() * sizeof *pixels);

	/*print(pixels + 0 * w() + 0, w(), 0x000000ul, txt);
	print(pixels + 0 * w() + 1, w(), 0x000000ul, txt);
	print(pixels + 0 * w() + 2, w(), 0x000000ul, txt);
	print(pixels + 1 * w() + 0, w(), 0x000000ul, txt);
	print(pixels + 1 * w() + 2, w(), 0x000000ul, txt);
	print(pixels + 2 * w() + 0, w(), 0x000000ul, txt);
	print(pixels + 2 * w() + 1, w(), 0x000000ul, txt);
	print(pixels + 2 * w() + 2, w(), 0x000000ul, txt);
	print(pixels + 1 * w() + 1, w(), 0xE0E0E0ul, txt);*/

	bitmapfont::print(pixels.get()              , w(), ShadeFill(), txt);
	bitmapfont::print(pixels.get() + 1 * w() + 1, w(), 0xE0E0E0ul , txt);
}

const uint_least32_t* ShadedTextOsdElment::update() {
	if (life--)
		return pixels;

	return 0;
}

/*class FramedTextOsdElment : public OsdElement {
	Array<uint_least32_t> const pixels;
	unsigned life;

public:
	FramedTextOsdElment(unsigned w, const char *txt);
	const uint_least32_t* update();
};

FramedTextOsdElment::FramedTextOsdElment(unsigned width, const char *txt) :
OsdElement(NUMBER_WIDTH, 144 - HEIGHT * 2 - HEIGHT / 2, width + NUMBER_WIDTH * 2, HEIGHT * 2),
pixels(std::size_t(w()) * h()),
life(4 * 60) {
	std::memset(pixels, 0x00, pixels.size() * sizeof *pixels);
	print(pixels + (w() - width) / 2 + std::size_t(h() - HEIGHT) / 2 * w(), w(), 0xA0A0A0ul, txt);
}

const uint_least32_t* FramedTextOsdElment::update() {
	if (life--)
		return pixels;

	return 0;
}*/

class SaveStateOsdElement : public OsdElement {
	uint_least32_t pixels[StateSaver::ss_width * StateSaver::ss_height];
	unsigned life;

public:
	SaveStateOsdElement(const std::string &fileName, unsigned stateNo);
	const uint_least32_t* update();
};

SaveStateOsdElement::SaveStateOsdElement(const std::string &fileName, unsigned stateNo)
: OsdElement(  (stateNo ? stateNo - 1 : 9) * ((160 - StateSaver::ss_width) / 10)
               + (160 - StateSaver::ss_width) / 10 / 2,
             4, StateSaver::ss_width, StateSaver::ss_height)
, life(4 * 60)
{
	std::ifstream file(fileName.c_str(), std::ios_base::binary);

	if (file) {
		file.ignore(5);
		file.read(reinterpret_cast<char*>(pixels), sizeof pixels);
	} else {
		std::memset(pixels, 0, sizeof pixels);

		using namespace bitmapfont;
		static const char txt[] = { E,m,p,t,bitmapfont::y,0 };
		print(pixels + 3 + (StateSaver::ss_height / 2 - bitmapfont::HEIGHT / 2) * StateSaver::ss_width,
		      StateSaver::ss_width, 0x808080ul, txt);
	}
}

const uint_least32_t* SaveStateOsdElement::update() {
	if (life--)
		return pixels;

	return 0;
}

} // anon namespace

namespace gambatte {

transfer_ptr<OsdElement> newStateLoadedOsdElement(unsigned stateNo) {
	char txt[sizeof text::stateLoaded];
	std::memcpy(txt, text::stateLoaded, sizeof txt);
	bitmapfont::utoa(stateNo, txt + 6);

	return transfer_ptr<OsdElement>(new ShadedTextOsdElment(text::stateLoadedWidth, txt));
}

transfer_ptr<OsdElement> newStateSavedOsdElement(unsigned stateNo) {
	char txt[sizeof text::stateSaved];
	std::memcpy(txt, text::stateSaved, sizeof txt);
	bitmapfont::utoa(stateNo, txt + 6);

	return transfer_ptr<OsdElement>(new ShadedTextOsdElment(text::stateSavedWidth, txt));
}

transfer_ptr<OsdElement> newSaveStateOsdElement(const std::string &fileName, unsigned stateNo) {
	return transfer_ptr<OsdElement>(new SaveStateOsdElement(fileName, stateNo));
}

}
