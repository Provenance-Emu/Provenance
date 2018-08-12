/*  Copyright 2008 Guillaume Duhamel
  
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

#ifndef MINI18N_PV_HASH_H
#define MINI18N_PV_HASH_H

#include "mini18n_pv_list.h"

#define MINI18N_HASH_SIZE 256

typedef struct _mini18n_hash_t mini18n_hash_t;

struct _mini18n_hash_t {
	mini18n_data_t * data;
	mini18n_list_t * list[MINI18N_HASH_SIZE];
};

mini18n_hash_t * mini18n_hash_init(mini18n_data_t * data);
void mini18n_hash_free(mini18n_hash_t * hash);
void mini18n_hash_add(mini18n_hash_t * hash, const char * key, const char * value);
const char * mini18n_hash_value(mini18n_hash_t * hash, const char * key);

mini18n_hash_t * mini18n_hash_from_file(const char * filename);

#endif
