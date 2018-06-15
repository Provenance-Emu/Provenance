/*  Copyright 2009 Guillaume Duhamel
  
    This file is part of mini18n.
  
    mini18n is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
  
    mini18n is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
  
    You should have received a copy of the GNU General Public License
    along with mini18n; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "mini18n.h"
#include "mini18n_pv_file_csv.h"

void remove_up_to(char buffer[], char c)
{
   char* pos = strchr(buffer, c);

   if (pos)
   {
      size_t diff = pos - buffer;
      memmove(buffer, buffer + diff + 1, strlen(buffer));
   }
}

void get_key_value(char buffer[], char dest[])
{
   char* pos = strchr(buffer, '\"');

   if (pos)
   {
      size_t diff = pos - buffer;
      memmove(dest, buffer, (size_t)diff);
      memmove(buffer, buffer + diff, strlen(buffer));
   }
}

int file_csv_load(mini18n_hash_t * hash, FILE * f) {
   char buffer[1024] = { 0 };
   char key[1024] = { 0 };
   char value[1024] = { 0 };

   while (fgets(buffer, 1024, f)) {
      int i = 0, j = 0, done = 0, state = 0, empty = 1;
      char c;

      if ((strlen(buffer) > 3) && buffer[0] == '\"')
      {
         //key
         remove_up_to(buffer, '\"');
         get_key_value(buffer, key);
         remove_up_to(buffer, '\"');

         //separator
         remove_up_to(buffer, ',');

         //value
         remove_up_to(buffer, '\"');
         get_key_value(buffer, value);

         //untranslated strings are empty
         if (!strlen(value))
            strcpy(value, key);

         done = 1;
         empty = 0;
      }

      if (done && !empty) {
         mini18n_hash_add(hash, key, value);
      }

      memset(buffer, 0, sizeof(char) * 1024);
      memset(key, 0, sizeof(char) * 1024);
      memset(value, 0, sizeof(char) * 1024);
   }

   return 0;
}

mini18n_file_t mini18n_file_csv = {
	file_csv_load
};