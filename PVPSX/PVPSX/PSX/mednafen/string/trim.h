#ifndef __MDFN_STRING_TRIM_H
#define __MDFN_STRING_TRIM_H

void MDFN_ltrim(char *string);
void MDFN_rtrim(char *string);
void MDFN_trim(char *string);

void MDFN_ltrim(std::string &string);
void MDFN_rtrim(std::string &string);
void MDFN_trim(std::string &string);

char *MDFN_RemoveControlChars(char *str);

#endif
