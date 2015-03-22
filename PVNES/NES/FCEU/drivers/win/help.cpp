#include "main.h"
#include "help.h"

#ifdef NEED_MINGW_HACKS

using std::string;

void OpenHelpWindow(string subpage)
{
	// TODO: Implement replacement for MinGW.
}

#else

#include <htmlhelp.h>

using std::string;

void OpenHelpWindow(string subpage)
{
	string helpFileName = BaseDirectory;
	helpFileName += "\\fceux.chm";
	if (subpage.length())
		helpFileName = helpFileName + "::/" + subpage + ".htm";
	HtmlHelp(GetDesktopWindow(), helpFileName.c_str(), HH_DISPLAY_TOPIC, (DWORD)NULL);
}

#endif