#define MAXIMUM_NUMBER_OF_LOGS 1024

#define DONT_ADD_NEWLINE 0
#define DO_ADD_NEWLINE 1

void MakeLogWindow(void);
void AddLogText(const char *text, unsigned int add_newline);
void ClearLog();
