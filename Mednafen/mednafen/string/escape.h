#ifndef __MDFN_ESCAPE_H
#define __MDFN_ESCAPE_H

// These functions are safe to call before calling MDFNI_Initialize().

void unescape_string(char *string);
char* escape_string(const char *text);

#endif
