/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* console.h:
**  Copyright (C) 2006-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

class MDFNConsole
{
	public:
	MDFNConsole(bool shellstyle = 0);
	~MDFNConsole();

	void ShowPrompt(bool shown);

	// Returns pointer to internal surface, will remain valid until at least the next
	// call to Draw()(or the MDFNConsole object is destroyed).
	MDFN_Surface* Draw(const MDFN_PixelFormat& pformat, const int32 dim_w, const int32 dim_h, const unsigned fontid = MDFN_FONT_9x18_18x18, const uint32 hex_color = 0xFFFFFF); //, const uint32 hex_cursorcolor = 0x00AA00);

	bool Event(const SDL_Event *event);

	void WriteLine(const std::string &text);
	void AppendLastLine(const std::string &text);
        virtual bool TextHook(const std::string &text);

	void SetShellStyle(bool newsetting) { shellstyle = newsetting; }
	void Scroll(int32 amount, bool SetPos = FALSE);

	private:
	std::vector<std::string> TextLog;
	std::u32string kb_buffer;

	size_t kb_cursor_pos;
	bool shellstyle;
	bool prompt_visible;
	int32 Scrolled;
	uint8 opacity;

	int32 ScrolledVecTarg;
	int32 LastPageSize;

	// Outside of the constructor and destructor, only mess with surface and tmp_surface
	// inside Draw(), for the Draw() return value guarantee.
	std::unique_ptr<MDFN_Surface> surface;
	std::unique_ptr<MDFN_Surface> tmp_surface;

	void PasteText(const std::u32string& text);
	void ProcessKBBuffer(void);
};
