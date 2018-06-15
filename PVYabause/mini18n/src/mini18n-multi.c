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

#include "mini18n.h"
#include "mini18n-multi.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mini18n_pv_hash.h"
#include "mini18n_pv_conv.h"
#ifdef _WIN32
#include "mini18n_pv_conv_windows.h"
#endif

typedef struct _mini18n_lang_t mini18n_lang_t;
struct _mini18n_lang_t {
	mini18n_hash_t * hash[1 + MINI18N_FORMAT_COUNT];
	FILE * log;
};

static mini18n_conv_t * converters[] = {
#ifdef _WIN32
	&mini18n_conv_windows_utf16,
#endif
	NULL
};

mini18n_t mini18n_create() {
	mini18n_lang_t * lang;
	int i;

	lang = malloc(sizeof(mini18n_lang_t));
	if (lang == NULL)
		return NULL;

	lang->log = NULL;

	for(i = 0;i < 1 + MINI18N_FORMAT_COUNT;i++)
		lang->hash[i] = NULL;

	return lang;
}

#ifdef _WIN32
#include <windows.h>
static char pathsep = '\\';

static void mini18n_pv_get_locale(char ** lang, char ** country) {
	char buffer[11];
	int i;
	LCID locale;

	*lang = malloc(3);
	*country = malloc(6);

	locale = GetUserDefaultLCID();
	GetLocaleInfo(locale, LOCALE_SABBREVLANGNAME, buffer, 10);
	for(i = 0;i < 2;i++) {
		(*lang)[i] = tolower(buffer[i]);
		(*country)[i] = tolower(buffer[i]);
	}
	(*country)[i++] = '_';
	GetLocaleInfo(locale, LOCALE_SABBREVCTRYNAME, buffer, 10);
	for(;i < 5;i++) {
		(*country)[i] = toupper(buffer[i - 3]);
	}
	(*lang)[2] = '\0';
	(*country)[5] = '\0';
}
#else
static char pathsep = '/';

static void mini18n_pv_get_locale(char ** lang, char ** country) {
	char * tmp;

	*country = "";
	*lang = NULL;
	tmp = getenv("LANG");
	if (tmp == NULL) return;

	*lang = strdup(tmp);

	tmp = strchr(*lang, '@');
	if (tmp != NULL) *tmp = '\0';
	tmp = strchr(*lang, '.');
	if (tmp != NULL) *tmp = '\0';
	tmp = strchr(*lang, '_');
	if (tmp != NULL) {
		*country = strdup(*lang);
		*tmp = '\0';
	}
}
#endif

int mini18n_load_system(mini18n_t lang, const char * folder) {
	mini18n_lang_t * impl = lang;
	char * lang_s;
	char * country;
	char * locale;
	char * fulllocale;

	if (impl == NULL) return -1;

	mini18n_pv_get_locale(&lang_s, &country);

	if (lang_s == NULL) return -1;

	if (folder == NULL) {
		locale = strdup(lang_s);
		fulllocale = strdup(country);
	} else {
		char * pos;
		size_t n = strlen(folder);

		if (n == 0) {
			locale = strdup(lang_s);
			fulllocale = strdup(country);
		} else {
			size_t s;
			int trailing = folder[n - 1] == pathsep ? 1 : 0;

			s = n + strlen(lang_s) + 5 + (1 - trailing);
			locale = malloc(s);

			pos = locale;
			pos += sprintf(pos, "%s", folder);
			if (! trailing) pos += sprintf(pos, "%c", pathsep);
			sprintf(pos, "%s.yts", lang_s);

			if (country == NULL) {
				fulllocale = NULL;
			} else {
				s = n + strlen(country) + 5 + (1 - trailing);
				fulllocale = malloc(s);

				pos = fulllocale;
				pos += sprintf(pos, "%s", folder);
				if (! trailing) pos += sprintf(pos, "%c", pathsep);
				sprintf(pos, "%s.yts", country);
			}
		}
	}

	if (mini18n_load(impl, fulllocale) == -1) {
		return mini18n_load(impl, locale);
	}

	return 0;
}

int mini18n_load(mini18n_t lang, const char * locale) {
	mini18n_lang_t * impl = lang;
	int i;
	mini18n_hash_t * tmp;

	if (impl == NULL) return -1;

	tmp = mini18n_hash_from_file(locale);
	if (tmp == NULL) return -1;

	for (i = 0;i < 1 + MINI18N_FORMAT_COUNT;i++) {
		mini18n_hash_free(impl->hash[i]);
		impl->hash[i] = i == 0 ? tmp : NULL;
	}

	return 0;
}

int mini18n_set_log_filename(mini18n_t lang, const char * filename) {
#ifdef MINI18N_LOG
	mini18n_lang_t * impl = lang;

	if (impl == NULL) return -1;

	impl->log = fopen(filename, "a");

	if (impl->log == NULL) {
		return -1;
	}
#endif

	return 0;
}

const char * mini18n_get(mini18n_t lang, const char * source) {
	mini18n_lang_t * impl = lang;
	const char * translated;

	if (impl == NULL) return source;

	translated = mini18n_hash_value(impl->hash[0], source);

#ifdef MINI18N_LOG
	if ((impl->log) && (impl->hash[0]) && (translated == source)) {
		unsigned int i = 0;
		unsigned int n = strlen(source);

		for(i = 0;i < n;i++) {
			switch(source[i]) {
				case '|':
					fprintf(impl->log, "\\|");
					break;
				case '\\':
					fprintf(impl->log, "\\\\");
					break;
				default:
					fprintf(impl->log, "%c", source[i]);
					break;
			}
		}
		if ( n > 0 )
			fprintf(impl->log, "|\n");

		/* we add the non translated string to avoid duplicates in the log file */
		mini18n_hash_add(impl->hash[0], source, translated);
	}
#endif

	return translated;
}

const void * mini18n_get_with_conversion(mini18n_t lang, const char * source, unsigned int format) {
	mini18n_lang_t * impl = lang;
	mini18n_conv_t * converter;
	const void * conv;

	if (impl == NULL) return "";

	if (impl->hash[format] != NULL) {
		conv = mini18n_hash_value(impl->hash[format], source);
		if (conv != source) return conv;
	}

	converter = *converters;

	while(converter != NULL) {
		if (converter->format == format) {
			conv = converter->conv(mini18n_get(impl, source));
			if (impl->hash[format] == NULL) impl->hash[format] = mini18n_hash_init(converter->data);
			mini18n_hash_add(impl->hash[format], source, conv);
			return conv;
		}
		converter++;
	}

	return "";
}

void mini18n_destroy(mini18n_t lang) {
	mini18n_lang_t * impl = lang;
	int i;

	if (impl == NULL) return;

	for(i = 0;i < 1 + MINI18N_FORMAT_COUNT;i++) {
		mini18n_hash_free(impl->hash[i]);
	}
#ifdef MINI18N_LOG
	if (impl->log) fclose(impl->log);
#endif
	free(impl);
}
