/*  Copyright 2010 Guillaume Duhamel
  
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

#ifndef MINI18N_MULTI_H
#define MINI18N_MULTI_H

#ifdef __cplusplus
extern "C" {
#endif

#include "mini18n.h"

typedef void * mini18n_t;

DLL_PUBLIC mini18n_t mini18n_create(void);
DLL_PUBLIC int mini18n_load_system(mini18n_t lang, const char * folder);
DLL_PUBLIC int mini18n_load(mini18n_t lang, const char * locale);
DLL_PUBLIC int mini18n_set_log_filename(mini18n_t lang, const char * filename);
DLL_PUBLIC const char * mini18n_get(mini18n_t lang, const char * source);
DLL_PUBLIC const void * mini18n_get_with_conversion(mini18n_t lang, const char * source, unsigned int format);
DLL_PUBLIC void mini18n_destroy(mini18n_t lang);

#ifdef __cplusplus
}
#endif

#endif
