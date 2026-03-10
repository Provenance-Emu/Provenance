/*
 * cuefile handling
 * (C) notaz, 2008
 * (C) irixxxx, 2020-2023
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../pico_int.h"
#include "cd_parse.h"
// #define elprintf(w,f,...) printf(f "\n",##__VA_ARGS__);

#if defined(USE_LIBCHDR)
#include "libchdr/chd.h"
#include "libchdr/cdrom.h"
#endif

#ifdef _MSC_VER
#define snprintf _snprintf
#endif
#ifdef __EPOC32__
#define snprintf(b,s,...) sprintf(b,##__VA_ARGS__)
#endif

static char *mystrip(char *str)
{
	int i, len;

	len = strlen(str);
	for (i = 0; i < len; i++)
		if (str[i] != ' ') break;
	if (i > 0) memmove(str, str + i, len - i + 1);

	len = strlen(str);
	for (i = len - 1; i >= 0; i--)
		if (str[i] != ' ' && str[i] != '\r' && str[i] != '\n') break;
	str[i+1] = 0;

	return str;
}

static int get_token(const char *buff, char *dest, int len)
{
	const char *p = buff;
	char sep = ' ';
	int d = 0, skip = 0;

	while (*p && *p == ' ') {
		skip++;
		p++;
	}

	if (*p == '\"') {
		sep = '\"';
		p++;
	}
	while (*p && *p != sep && d < len-1)
		dest[d++] = *p++;
	dest[d] = 0;

	if (sep == '\"' && *p != sep)
		elprintf(EL_STATUS, "cue: bad token: \"%s\"", buff);

	return d + skip;
}

static int get_ext(const char *fname, char ext[4],
	char *base, size_t base_size)
{
	size_t pos = 0;
	char *p;
	
	ext[0] = 0;
	if (!(p = strrchr(fname, '.')))
		return -1;
	pos = p - fname;

	strncpy(ext, fname + pos + 1, 4/*sizeof(ext)*/-1);
	ext[4/*sizeof(ext)*/-1] = '\0';

	if (base != NULL && base_size > 0) {
		if (pos >= base_size)
			pos = base_size - 1;

		memcpy(base, fname, pos);
		base[pos] = 0;
	}
	return pos;
}

static void change_case(char *p, int to_upper)
{
	for (; *p != 0; p++) {
		if (to_upper && 'a' <= *p && *p <= 'z')
			*p += 'A' - 'a';
		else if (!to_upper && 'A' <= *p && *p <= 'Z')
			*p += 'a' - 'A';
	}
}

static int file_openable(const char *fname)
{
	FILE *f = fopen(fname, "rb");
	if (f == NULL)
		return 0;
	fclose(f);
	return 1;
}

#define BEGINS(buff,str) (strncmp(buff,str,sizeof(str)-1) == 0)

/* note: tracks[0] is not used */
cd_data_t *chd_parse(const char *fname)
{
	cd_data_t *data = NULL;
#if defined(USE_LIBCHDR)
	cd_data_t *tmp;
	int count = 0, count_alloc = 2;
	int sectors = 0;
	char metadata[256];
	chd_file *cf = NULL;

	if (fname == NULL || *fname == '\0')
		return NULL;

	if (chd_open(fname, CHD_OPEN_READ, NULL, &cf) != CHDERR_NONE)
		goto out;

	data = calloc(1, sizeof(*data) + count_alloc * sizeof(cd_track_t));
	if (data == NULL)
		goto out;

	// get track info
	while (count < CD_MAX_TRACKS) {
		int track = 0, frames = 0, pregap = 0, postgap = 0;
		char type[16], subtype[16], pgtype[16], pgsub[16];
		type[0] = subtype[0] = pgtype[0] = pgsub[0] = 0;

		// get metadata for track
		if (chd_get_metadata(cf, CDROM_TRACK_METADATA2_TAG, count,
			metadata, sizeof(metadata), 0, 0, 0) == CHDERR_NONE) {
			if (sscanf(metadata, CDROM_TRACK_METADATA2_FORMAT,
				&track, &type[0], &subtype[0], &frames,
				&pregap, &pgtype[0], &pgsub[0], &postgap) != 8)
			break;
		}
		else if (chd_get_metadata(cf, CDROM_TRACK_METADATA_TAG, count,
			metadata, sizeof(metadata), 0, 0, 0) == CHDERR_NONE) {
			if (sscanf(metadata, CDROM_TRACK_METADATA_FORMAT,
				&track, &type[0], &subtype[0], &frames) != 4)
			break;
		}
		else break;	// all tracks completed

		// metadata sanity check
		if (track != count + 1 || frames < 0 || pregap < 0)
			break;

		// allocate track structure
		count ++;
		if (count >= count_alloc) {
			count_alloc *= 2;
			tmp = realloc(data, sizeof(*data) + count_alloc * sizeof(cd_track_t));
			if (tmp == NULL) {
				count--;
				break;
			}
			data = tmp;
		}
		memset(&data->tracks[count], 0, sizeof(data->tracks[0]));

		if (count == 1)
			data->tracks[count].fname = strdup(fname);
	        if (!strcmp(type, "MODE1_RAW") || !strcmp(type, "MODE2_RAW")) {
		        data->tracks[count].type = CT_BIN;
	        } else if (!strcmp(type, "MODE1") || !strcmp(type, "MODE2_FORM1")) {
			data->tracks[count].type = CT_ISO;
		} else if (!strcmp(type, "AUDIO")) {
			data->tracks[count].type = CT_CHD;
		} else
			break;

		data->tracks[count].pregap = pregap;
		if (pgtype[0] != 'V')	// VAUDIO includes pregap in file
			pregap = 0;
		data->tracks[count].sector_offset = sectors + pregap;
		data->tracks[count].sector_xlength = frames - pregap;
		sectors += (((frames + CD_TRACK_PADDING - 1) / CD_TRACK_PADDING) * CD_TRACK_PADDING);
	}

	// check if image id OK, i.e. there are tracks, and length <= 80 min
	if (count && sectors < (80*60*75)) {
		data->track_count = count;
	}  else {
		free(data);
		data = NULL;
	}

out:
	if (cf)
		chd_close(cf);
#endif
	return data;
}

cd_data_t *cue_parse(const char *fname)
{
	char current_file[256], *current_filep, cue_base[256];
	char buff[256], buff2[32], ext[4], *p;
	int ret, count = 0, count_alloc = 2, pending_pregap = 0;
	size_t current_filep_size, fname_len;
	cd_data_t *data = NULL, *tmp;
	FILE *f = NULL;

	if (fname == NULL || (fname_len = strlen(fname)) == 0)
		return NULL;

	ret = get_ext(fname, ext, cue_base, sizeof(cue_base) - 4);
	if (strcasecmp(ext, "cue") == 0) {
		f = fopen(fname, "r");
	}
	else if (strcasecmp(ext, "chd") != 0) {
		// not a .cue, try one with the same base name
		if (0 < ret && ret < sizeof(cue_base)) {
			strcpy(cue_base + ret, ".cue");
			f = fopen(cue_base, "r");
			if (f == NULL) {
				strcpy(cue_base + ret, ".CUE");
				f = fopen(cue_base, "r");
			}
		}
	}

	if (f == NULL)
		return NULL;

	snprintf(current_file, sizeof(current_file), "%s", fname);
	current_filep = current_file + strlen(current_file);
	for (; current_filep > current_file; current_filep--)
		if (current_filep[-1] == '/' || current_filep[-1] == '\\')
			break;

	current_filep_size = sizeof(current_file) - (current_filep - current_file);

	// the basename of cuefile, no path
	snprintf(cue_base, sizeof(cue_base), "%s", current_filep);
	p = strrchr(cue_base, '.');
	if (p)	p[1] = '\0';

	data = calloc(1, sizeof(*data) + count_alloc * sizeof(cd_track_t));
	if (data == NULL)
		goto out;

	while (!feof(f))
	{
		if (fgets(buff, sizeof(buff), f) == NULL)
			break;

		mystrip(buff);
		if (buff[0] == 0)
			continue;
		if      (BEGINS(buff, "TITLE ") || BEGINS(buff, "PERFORMER ") || BEGINS(buff, "SONGWRITER "))
			continue;	/* who would put those here? Ignore! */
		else if (BEGINS(buff, "FILE "))
		{
			get_token(buff + 5, current_filep, current_filep_size);
		}
		else if (BEGINS(buff, "TRACK "))
		{
			count++;
			if (count >= count_alloc) {
				count_alloc *= 2;
				tmp = realloc(data, sizeof(*data) + count_alloc * sizeof(cd_track_t));
				if (tmp == NULL) {
					count--;
					break;
				}
				data = tmp;
			}
			memset(&data->tracks[count], 0, sizeof(data->tracks[0]));

			if (count == 1 || strcmp(data->tracks[1].fname, current_file) != 0)
			{
				if (file_openable(current_file))
					goto file_ok;

				elprintf(EL_STATUS, "cue: bad/missing file: \"%s\"", current_file);
				if (count == 1) {
					int cue_ucase;
					char v;

					get_ext(current_file, ext, NULL, 0);
					snprintf(current_filep, current_filep_size,
						"%s%s", cue_base, ext);
					if (file_openable(current_file))
						goto file_ok;

					// try with the same case (for unix)
					v = fname[fname_len - 1];
					cue_ucase = ('A' <= v && v <= 'Z');
					change_case(ext, cue_ucase);

					snprintf(current_filep, current_filep_size,
						"%s%s", cue_base, ext);
					if (file_openable(current_file))
						goto file_ok;
				}

				count--;
				break;

file_ok:
				data->tracks[count].fname = strdup(current_file);
				if (data->tracks[count].fname == NULL)
					break;
			}
			data->tracks[count].pregap = pending_pregap;
			pending_pregap = 0;
			// track number
			ret = get_token(buff+6, buff2, sizeof(buff2));
			if (count != atoi(buff2))
				elprintf(EL_STATUS, "cue: track index mismatch: track %i is track %i in cue",
					count, atoi(buff2));
			// check type
			get_token(buff+6+ret, buff2, sizeof(buff2));
			if      (strcmp(buff2, "MODE1/2352") == 0)
				data->tracks[count].type = CT_BIN;
			else if (strcmp(buff2, "MODE1/2048") == 0)
				data->tracks[count].type = CT_ISO;
			else if (strcmp(buff2, "AUDIO") == 0)
			{
				if (data->tracks[count].fname != NULL)
				{
					// rely on extension, not type in cue..
					get_ext(data->tracks[count].fname, ext, NULL, 0);
					if      (strcasecmp(ext, "mp3") == 0)
						data->tracks[count].type = CT_MP3;
					else if (strcasecmp(ext, "wav") == 0)
						data->tracks[count].type = CT_WAV;
					else if (strcasecmp(ext, "bin") == 0)
						data->tracks[count].type = CT_RAW;
					else {
						elprintf(EL_STATUS, "unhandled audio format: \"%s\"",
							data->tracks[count].fname);
					}
				}
				else if (data->tracks[count-1].type & CT_AUDIO)
				{
					// propagate previous
					data->tracks[count].type = data->tracks[count-1].type;
				}
				else
				{
					// assume raw binary data
					data->tracks[count].type = CT_RAW;
				}
			}
			else {
				elprintf(EL_STATUS, "unhandled track type: \"%s\"", buff2);
			}
		}
		else if (BEGINS(buff, "INDEX "))
		{
			int m, s, f;
			// type
			ret = get_token(buff+6, buff2, sizeof(buff2));
			if (atoi(buff2) == 0) continue;
			if (atoi(buff2) != 1) {
				elprintf(EL_STATUS, "cue: don't know how to handle: \"%s\"", buff);
				count--; break;
			}
			// offset in file
			get_token(buff+6+ret, buff2, sizeof(buff2));
			ret = sscanf(buff2, "%d:%d:%d", &m, &s, &f);
			if (ret != 3) {
				elprintf(EL_STATUS, "cue: failed to parse: \"%s\"", buff);
				count--; break;
			}
			data->tracks[count].sector_offset = m*60*75 + s*75 + f;
			// some strange .cues may need this
			if (data->tracks[count].fname != NULL && strcmp(data->tracks[count].fname, current_file) != 0)
			{
				free(data->tracks[count].fname);
				data->tracks[count].fname = strdup(current_file);
			}
			if (data->tracks[count].fname == NULL && strcmp(data->tracks[1].fname, current_file) != 0)
			{
				data->tracks[count].fname = strdup(current_file);
			}
		}
		else if (BEGINS(buff, "PREGAP ") || BEGINS(buff, "POSTGAP "))
		{
			int m, s, f;
			get_token(buff+7, buff2, sizeof(buff2));
			ret = sscanf(buff2, "%d:%d:%d", &m, &s, &f);
			if (ret != 3) {
				elprintf(EL_STATUS, "cue: failed to parse: \"%s\"", buff);
				continue;
			}
			// pregap overrides previous postgap?
			// by looking at some .cues produced by some programs I've decided that..
			if (BEGINS(buff, "PREGAP "))
				data->tracks[count].pregap = m*60*75 + s*75 + f;
			else
				pending_pregap = m*60*75 + s*75 + f;
		}
		else if (BEGINS(buff, "REM LENGTH ")) // custom "extension"
		{
			int m, s, f;
			get_token(buff+11, buff2, sizeof(buff2));
			ret = sscanf(buff2, "%d:%d:%d", &m, &s, &f);
			if (ret != 3) continue;
			data->tracks[count].sector_xlength = m*60*75 + s*75 + f;
		}
		else if (BEGINS(buff, "REM NOLOOP")) // MEGASD "extension"
		{
			data->tracks[count].loop = -1;
		}
		else if (BEGINS(buff, "REM LOOP")) // MEGASD "extension"
		{
			int lba;
			get_token(buff+8, buff2, sizeof(buff2));
			ret = sscanf(buff2, "%d", &lba);
			if (ret != 1) lba = 0;
			data->tracks[count].loop_lba = lba;
			data->tracks[count].loop = 1;
		}
		else if (BEGINS(buff, "REM"))
			continue;
		else
		{
			elprintf(EL_STATUS, "cue: unhandled line: \"%s\"", buff);
		}
	}

	if (count < 1 || data->tracks[1].fname == NULL) {
		// failed..
		for (; count > 0; count--)
			if (data->tracks[count].fname != NULL)
				free(data->tracks[count].fname);
		free(data);
		data = NULL;
		goto out;
	}

	data->track_count = count;

out:
	if (f != NULL)
		fclose(f);
	return data;
}


void cdparse_destroy(cd_data_t *data)
{
	int c;

	if (data == NULL) return;

	for (c = data->track_count; c > 0; c--)
		if (data->tracks[c].fname != NULL)
			free(data->tracks[c].fname);
	free(data);
}


#if 0
int main(int argc, char *argv[])
{
	cd_data_t *data = cue_parse(argv[1]);
	int c;

	if (data == NULL) return 1;

	for (c = 1; c <= data->track_count; c++)
		printf("%2i: %i %9i %02i:%02i:%02i %9i %s\n", c, data->tracks[c].type, data->tracks[c].sector_offset,
			data->tracks[c].sector_offset / (75*60), data->tracks[c].sector_offset / 75 % 60,
			data->tracks[c].sector_offset % 75, data->tracks[c].pregap, data->tracks[c].fname);

	cdparse_destroy(data);

	return 0;
}
#endif

