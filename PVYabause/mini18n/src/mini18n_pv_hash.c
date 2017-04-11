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

#include "mini18n_pv_hash.h"
#include "mini18n_pv_file.h"
#include "mini18n_pv_file_yts.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

static mini18n_file_t * loaders[] = {
	&mini18n_file_yts,
	NULL
};

static unsigned int mini18n_hash_func(mini18n_hash_t * hash, const char * key);

mini18n_hash_t * mini18n_hash_init(mini18n_data_t * data) {
	mini18n_hash_t * hash;
	int i;

	hash = malloc(sizeof(mini18n_hash_t));
	if (hash == NULL) {
		return NULL;
	}

	hash->data = data;

	for(i = 0;i < MINI18N_HASH_SIZE;i++) {
		hash->list[i] = mini18n_list_init();
	}

	return hash;
}

void mini18n_hash_free(mini18n_hash_t * hash) {
	int i;

	if (hash == NULL) {
		return;
	}

	for(i = 0;i < MINI18N_HASH_SIZE;i++) {
		mini18n_list_free(hash->list[i]);
	}

	free(hash);
}

void mini18n_hash_add(mini18n_hash_t * hash, const char * key, const char * value) {
	unsigned int h;

	h = mini18n_hash_func(hash, key);

	hash->list[h] = mini18n_list_add(hash->list[h], key, hash->data, value);
}

const char * mini18n_hash_value(mini18n_hash_t * hash, const char * key) {
	unsigned int h;

	if (hash == NULL) {
		return key;
	}

	h = mini18n_hash_func(hash, key);

	return mini18n_list_value(hash->list[h], key);
}

unsigned int mini18n_hash_func(mini18n_hash_t * hash, const char * key) {
	unsigned int i, s = 0;
	int n = hash->data->len(key);

	for(i = 0;i < n;i++) {
		s+= key[i];
		s %= MINI18N_HASH_SIZE;
	}

	return s;
}

mini18n_hash_t * mini18n_hash_from_file(const char * filename) {
	mini18n_hash_t * hash;
	FILE * f;
	mini18n_file_t * file;

	if (filename == NULL)
		return NULL;

	hash = mini18n_hash_init(&mini18n_str);
	if (hash == NULL)
		return NULL;

	f = fopen(filename, "r");
	if (f == NULL) {
		mini18n_hash_free(hash);
		return NULL;
	}

	file = *loaders;
	while(file != NULL) {
		if (file->load(hash, f) == 0) {
			fclose(f);
			return hash;
		}
		file++;
	}

	fclose(f);
	return hash;
}
