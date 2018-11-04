/*
  PokeMini Music Converter
  Copyright (C) 2011-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

void (*raw_handle_callback)(void) = 0;

#ifdef _WIN32

#include <conio.h>
#include <windows.h>

int raw_input_check(void)
{
	return kbhit();
}

BOOL CtrlHandler(DWORD fdwCtrlType)
{ 
	switch (fdwCtrlType) {
	case CTRL_C_EVENT:
		if (raw_handle_callback) raw_handle_callback();
		return TRUE;
	default:
		return FALSE;
	}
}

void raw_handle_ctrlc(void (*func)(void))
{
	raw_handle_callback = func;
	SetConsoleCtrlHandler((PHANDLER_ROUTINE)CtrlHandler, TRUE);
	/*
	DWORD ConMode;
	HANDLE StdIn = GetStdHandle(STD_INPUT_HANDLE);
	GetConsoleMode(StdIn, &ConMode);
	SetConsoleMode(StdIn, ConMode & ~ENABLE_PROCESSED_INPUT);
	*/
}

#else

#include <termios.h>
#include <unistd.h>
#include <sys/select.h>
#include <signal.h>

int raw_input_check(void)
{
	fd_set set;
	struct termios oldterm, newterm;
	struct timeval tv;
	int res;

	// Backup terminal
	tcgetattr(STDIN_FILENO, &oldterm );
	newterm = oldterm;

	// Set "raw" terminal mode
	newterm.c_lflag &= ~(ICANON | ECHO);
	tcsetattr(STDIN_FILENO, TCSANOW, &newterm);

	// Select for checking the input
	FD_ZERO(&set);
	FD_SET(STDIN_FILENO, &set);
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	res = select(STDIN_FILENO+1, &set, NULL, NULL, &tv);

	// Restore terminal
	tcsetattr(STDIN_FILENO, TCSANOW, &oldterm);

	return res;
}

void raw_handle_signal(int signo)
{
	if (raw_handle_callback) raw_handle_callback();
}

void raw_handle_ctrlc(void (*func)(void))
{
	raw_handle_callback = func;
	signal(SIGINT, raw_handle_signal);
}

#endif
