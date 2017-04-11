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

#include "mini18n_pv_list.h"
#include <string.h>
#include <stdlib.h>

mini18n_list_t * mini18n_list_init() {
	return NULL;
}

void mini18n_list_free(mini18n_list_t * list) {
	mini18n_list_t * node, * next;

	node = list;

	while(node != NULL) {
		next = node->next;

		free(node->key);
		free(node->value);
		free(node);

		node = next;
	}
}

mini18n_list_t * mini18n_list_add(mini18n_list_t * list, const char * key, mini18n_data_t * data, const char * value) {
	mini18n_list_t * node;

	node = malloc(sizeof(mini18n_list_t));
	if (node == NULL) {
		return list;
	}

	node->key = strdup(key);
	node->data = data;
	node->value = node->data->dup(value);
	node->next = list;

	return node;
}

const char * mini18n_list_value(mini18n_list_t * list, const char * key) {
	mini18n_list_t * node;

	node = list;
	while(node != NULL) {
		if (!node->data->cmp(key, node->key)) {
			return node->value;
		}

		node = node->next;
	}

	return key;
}
