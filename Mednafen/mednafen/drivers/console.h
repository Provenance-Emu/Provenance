#include <vector>
#include <string>

class MDFNConsole
{
	public:
	MDFNConsole(bool shellstyle = 0, unsigned setfont = MDFN_FONT_9x18_18x18);
	~MDFNConsole();

	void ShowPrompt(bool shown);
	void Draw(MDFN_Surface *surface, const MDFN_Rect *src_rect);

	int Event(const SDL_Event *event);

	void WriteLine(const std::string &text);
	void AppendLastLine(const std::string &text);
        virtual bool TextHook(const std::string &text);

	void SetFont(unsigned newfont) { Font = newfont; }
	void SetShellStyle(bool newsetting) { shellstyle = newsetting; }
	void Scroll(int32 amount, bool SetPos = FALSE);

	private:
	std::vector<std::string> TextLog;
	std::vector<std::string> kb_buffer;
	unsigned int kb_cursor_pos;
	bool shellstyle;
	bool prompt_visible;
	uint32 Scrolled;
	unsigned Font;
	uint8 opacity;
};
