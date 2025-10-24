#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0501
#endif

#if _WIN32_WINNT < 0x0501
#error Must target Windows NT 5.0.1 or later for DebugBreakProcess
#endif

#include <Windows.h>

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>

/* Compile with this line:

gcc -o debugbreak -mno-cygwin -mthreads debugbreak.c

*/

static char errbuffer[256];

static const char *geterrstr(DWORD errcode)
{
size_t skip = 0;
DWORD chars;
chars = FormatMessage(
FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
NULL, errcode, 0, errbuffer, sizeof(errbuffer)-1, 0);
errbuffer[sizeof(errbuffer)-1] = 0;
if (chars) {
while (errbuffer[chars-1] == '\r' || errbuffer[chars-1] == '\n') {
errbuffer[--chars] = 0;
}
}
if (chars && errbuffer[chars-1] == '.') errbuffer[--chars] = 0;
if (chars >= 2 && errbuffer[0] == '%' && errbuffer[1] >= '0'
&& errbuffer[1] <= '9')
{
skip = 2;
while (chars > skip && errbuffer[skip] == ' ') ++skip;
if (chars >= skip+2 && errbuffer[skip] == 'i'
&& errbuffer[skip+1] == 's')
{
skip += 2;
while (chars > skip && errbuffer[skip] == ' ') ++skip;
}
}
if (chars > skip && errbuffer[skip] >= 'A' && errbuffer[skip] <= 'Z') {
errbuffer[skip] += 'a' - 'A';
}
return errbuffer+skip;
}

int main(int argc, char *argv[])
{
    HANDLE proc;
    unsigned proc_id = 0;
    BOOL break_result;

    if (argc != 2) {
        printf("Usage: debugbreak process_id_number\n");
        return 1;
    }
    proc_id = (unsigned) strtol(argv[1], NULL, 0);
    if (proc_id == 0) {
        printf("Invalid process id %u\n", proc_id);
        return 1;
    }
    proc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, (DWORD)proc_id);
    if (proc == NULL) {
        DWORD lastError = GetLastError();
        printf("Failed to open process %u\n", proc_id);
        printf("Error code is %lu (%s)\n", (unsigned long)lastError,
            geterrstr(lastError));
        return 1;
    }
    break_result = DebugBreakProcess(proc);
    if (!break_result) {
        DWORD lastError = GetLastError();
        printf("Failed to debug break process %u\n", proc_id);
        printf("Error code is %lu (%s)\n", (unsigned long)lastError,
            geterrstr(lastError));
        CloseHandle(proc);
        return 1;
    }
    printf("DebugBreak sent successfully to process id %u\n", proc_id);
    CloseHandle(proc);
    return 0;
}

/* END debugbreak.c */
