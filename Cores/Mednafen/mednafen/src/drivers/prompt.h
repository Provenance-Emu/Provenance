#ifndef __MDFN_DRIVERS_PROMPT_H
#define __MDFN_DRIVERS_PROMPT_H

#include "TextEntry.h"

class HappyPrompt
{
	public:
	HappyPrompt(const std::string &ptext, const std::string &zestring);
	HappyPrompt();

	virtual ~HappyPrompt();

	void Draw(MDFN_Surface *surface, const MDFN_Rect *rect);
	void Event(const SDL_Event *event);
	void SetText(const std::string &ptext);
	void InsertKBB(const std::string &zestring);

        virtual void TheEnd(const std::string &pstring);


	protected:
        std::string PromptText;

	private:

	TextEntry te;
};

#endif
