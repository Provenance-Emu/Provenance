#include <stdlib.h>
#include "common.h"
#include "tracer.h"

static HWND logwin = 0;

static char *logtext[MAXIMUM_NUMBER_OF_LOGS];
static int logcount=0;

int MLogPosX=0,MLogPosY=0;	//X,Y coordinates of dialog

unsigned int truncated_logcount()
{
	return logcount & ( MAXIMUM_NUMBER_OF_LOGS - 1 );
}

/**
* Concatenates formerly logged messages into a single string and
* displays that string in the log window.
**/
void RedoText(void)
{
	char textbuf[65536] = { 0 };
	int x;
	int tbs=0; // textbuf size
	int cs; // current log size

	// TODO: This if can be made much simpler.
	if(logcount >= MAXIMUM_NUMBER_OF_LOGS)
	{

		x = truncated_logcount();

		for(;;)
		{
			cs=strlen(logtext[x]);
			if (tbs+cs>=65536)
			{
				//SetDlgItemText(logwin, LBL_LOG_TEXT, textbuf);
				//SendDlgItemMessage(logwin, LBL_LOG_TEXT, EM_LINESCROLL, 0, 200);
				//textbuf[0]='\0';
				//tbs=0;
				break;
			}
			strcat(textbuf+tbs, logtext[x]);
			tbs+=cs;
			x = ( x + 1 ) & ( MAXIMUM_NUMBER_OF_LOGS - 1 );

			if(x == truncated_logcount())
			{
				break;
			}
		}
	}
	else
	{
		for(x = 0; x < logcount; x++)
		{
			cs=strlen(logtext[x]);
			if (tbs+cs>=65536)
			{
				break;
			}
			strcat(textbuf+tbs,logtext[x]);
			tbs+=cs;
		}
	}

	SetDlgItemText(logwin, LBL_LOG_TEXT, textbuf);
	SendDlgItemMessage(logwin, LBL_LOG_TEXT, EM_LINESCROLL, 0, MAXIMUM_NUMBER_OF_LOGS);
}

/**
* Callback function for the log window.
**/
BOOL CALLBACK LogCon(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	RECT wrect;	//For remembering window position
	switch(uMsg)
	{
		case WM_INITDIALOG:
			if (MLogPosX==-32000) MLogPosX=0; //Just in case
			if (MLogPosY==-32000) MLogPosY=0;
			SetWindowPos(hwndDlg,0,MLogPosX,MLogPosY,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);
			break;
		case WM_MOVE:
			if (!IsIconic(hwndDlg)) {
			GetWindowRect(hwndDlg,&wrect);	//Remember X,Y coordinates
			MLogPosX = wrect.left;
			MLogPosY = wrect.top;

			#ifdef WIN32
			WindowBoundsCheckNoResize(MLogPosX,MLogPosY,wrect.right);
			#endif
			}
			break;
		case WM_COMMAND:
		{
			if (HIWORD(wParam) == BN_CLICKED)
			{
				if (LOWORD(wParam) == CLEAR_LOG)
				{
					ClearLog();
				} else
				{
					DestroyWindow(hwndDlg);
					// Clear the handle
					logwin = 0;
				}
			}
			break;
		}
	}

	return 0;
}

/**
* Creates the log window if it's not already open.
**/
void MakeLogWindow(void)
{
	if(!logwin)
	{
		logwin = CreateDialog(fceu_hInstance, "MESSAGELOG" , 0, LogCon);
		RedoText(); // XXX jeblanchard Why didn't this work in WM_INITDIALOG?
	} else
	{
		ShowWindow(logwin, SW_SHOWNORMAL);
		SetForegroundWindow(logwin);
	}
}

void ClearLog()
{
	for (logcount--; logcount >= 0; logcount--)
		free(logtext[truncated_logcount()]);
	logcount = 0;
	if (logwin)
		RedoText();
}

/**
* Adds a textual log message to the message buffer.
*
* @param text Message to add.
* @param add_newline Either DO_ADD_NEWLINE or DONT_ADD_NEWLINE
**/
void AddLogText(const char *text, unsigned int add_newline)
{
	// Used to count the number of new line characters in text
	int number_of_newlines;

	// Used to iterate over the text
	const char *text_iterator_c;

	// Used to iterate over the message log created in this function
	char* msg_iterator;

	// Free a log message if more messages than necessary were logged.
	if(logcount >= MAXIMUM_NUMBER_OF_LOGS)
	{
		free(logtext[truncated_logcount()]);
	}

	number_of_newlines = 0;
	text_iterator_c = text;

	// Count the number of \n characters in the text
	while(*text_iterator_c)
	{
		if(*text_iterator_c == '\n')
		{
			number_of_newlines++;
		}

		text_iterator_c++;
	}

	unsigned int necessary_size = strlen(text) // len(text)
		+ 1 // 0-byte
		+ number_of_newlines // Space for additional \r characters
		+ 2 * add_newline; // \r\n if a newline was requested

	//mbg merge 7/17/06 added cast
	logtext[truncated_logcount()] = (char*)malloc(necessary_size);

	// Apparently there's no memory left.
	if(!logtext[truncated_logcount()])
	{
		return;
	}

	msg_iterator = logtext[truncated_logcount()];

	// Copy the characters from text to the allocated buffer
	while(*text)
	{
		// Replace \n with \r\n
		if(*text == '\n')
		{
			*msg_iterator='\r';
			msg_iterator++;
		}

		*msg_iterator = *text;

		msg_iterator++;
		text++;
	}

	// Add a final newline if requested
	if (add_newline)
	{
		*msg_iterator = '\r';
		msg_iterator++;
		*msg_iterator = '\n';
		msg_iterator++;
	}

	// Terminating 0-byte
	*msg_iterator = 0;

	// also log the text into Trace Logger log if needed
	if (logging && (logging_options & LOG_MESSAGES))
	{
		OutputLogLine(strdup(logtext[truncated_logcount()]), 0, add_newline != 0);
		log_old_emu_paused = false;		// force Trace Logger update
	}

	// Keep track of the added log
	logcount++;

	if(logwin)
	{
		RedoText();
	}
}

/**
* Adds a textual message to the message buffer without adding a newline at the end.
*
* @param text The text of the message to add.
* 
* TODO: This function should have a better name.
**/
void FCEUD_Message(const char *text)
{
	AddLogText(text, DONT_ADD_NEWLINE);
}
