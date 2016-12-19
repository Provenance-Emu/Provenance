/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "../mednafen.h"
#include "trim.h"

// Remove whitespace from beginning of string
void MDFN_ltrim(char *string)
{
 int32 di, si;
 bool InWhitespace = TRUE;

 di = si = 0;

 while(string[si])
 {
  if(InWhitespace && (string[si] == ' ' || string[si] == '\r' || string[si] == '\n' || string[si] == '\t' || string[si] == 0x0b))
  {

  }
  else
  {
   InWhitespace = FALSE;
   string[di] = string[si];
   di++;
  }
  si++;
 }
 string[di] = 0;
}

// Remove whitespace from end of string
void MDFN_rtrim(char *string)
{
 int32 len = strlen(string);

 if(len)
 {
  for(int32 x = len - 1; x >= 0; x--)
  {
   if(string[x] == ' ' || string[x] == '\r' || string[x] == '\n' || string[x] == '\t' || string[x] == 0x0b)
    string[x] = 0;
   else
    break;
  }
 }

}

void MDFN_trim(char *string)
{
 MDFN_rtrim(string);
 MDFN_ltrim(string);
}


// Remove whitespace from beginning of string
void MDFN_ltrim(std::string &string)
{
 size_t len = string.length();
 size_t di, si;
 bool InWhitespace = TRUE;

 di = si = 0;

 while(si < len)
 {
  if(InWhitespace && (string[si] == ' ' || string[si] == '\r' || string[si] == '\n' || string[si] == '\t' || string[si] == 0x0b))
  {

  }
  else
  {
   InWhitespace = FALSE;
   string[di] = string[si];
   di++;
  }
  si++;
 }

 string.resize(di);
}

// Remove whitespace from end of string
void MDFN_rtrim(std::string &string)
{
 size_t len = string.length();

 if(len)
 {
  size_t x = len;
  size_t new_len = len;

  do
  {
   x--;

   if(!(string[x] == ' ' || string[x] == '\r' || string[x] == '\n' || string[x] == '\t' || string[x] == 0x0b))
    break;
 
   new_len--;
  } while(x);

  string.resize(new_len);
 }
}


void MDFN_trim(std::string &string)
{
 MDFN_rtrim(string);
 MDFN_ltrim(string);
}


char *MDFN_RemoveControlChars(char *str)
{
 char *orig = str;

 if(str)
 {
  while(*str)
  {
   if((unsigned char)*str < 0x20)
    *str = 0x20;
   str++;
  }
 }

 return(orig);
}

void MDFN_RemoveControlChars(std::string& string)
{
 for(size_t i = 0; i < string.size(); i++)
 {
  if((unsigned char)string[i] < 0x20)
   string[i] = 0x20;
 }
}
