/*  Copyright 2008 Guillaume Duhamel
    Copyright 2010 Lawrence Sebald
  
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

#include "mini18n_pv_data.h"
#include <string.h>
#define __USE_GNU
#include <wchar.h>

#ifndef HAVE_WCSDUP
#include <stdlib.h>
#include <errno.h>

/* wcsdup isn't technically part of C99 or anything, so there's at least a
   possibility it isn't defined on the system. */
static wchar_t *wcsdup(const wchar_t *string) {
    size_t len = wcslen(string) + 1;
    wchar_t *rv = (wchar_t *)malloc(len * sizeof(wchar_t));

    if(!rv) {
        errno = ENOMEM;
        return (wchar_t *)0;
    }

    /* wcsncpy will return rv, so this works. */
    return wcsncpy(rv, string, len);
}
    
#endif /* !HAVE_WCSDUP */

mini18n_data_t mini18n_str = {
	(mini18n_len_func) strlen,
	(mini18n_dup_func) strdup,
	(mini18n_cmp_func) strcmp
};


#ifndef HAVE_WCS_POINTERS
size_t wcslen_wrapper(const wchar_t *s) {
	return wcslen(s);
}
int wcscmp_wrapper(const wchar_t *s1, const wchar_t *s2) {
	return wcscmp(s1, s2);
}

mini18n_data_t mini18n_wcs = {
	(mini18n_len_func) wcslen_wrapper,
	(mini18n_dup_func) wcsdup,
	(mini18n_cmp_func) wcscmp_wrapper
};
#else
mini18n_data_t mini18n_wcs = {
	(mini18n_len_func) wcslen,
	(mini18n_dup_func) wcsdup,
	(mini18n_cmp_func) wcscmp
};
#endif
