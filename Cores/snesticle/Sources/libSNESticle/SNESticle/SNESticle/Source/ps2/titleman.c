/* titleman.c - TITLE.DB manager.
 *
 * Copyright (c) 2003  Marcus R. Brown <mrbrown@0xd6.org>
 *
 * This code is licensed under the Academic Free License v2.0.
 * See the file LICENSE included with this distribution for licensing terms.
 *
 * titleman is a host program that allows you to create, add, or remove
 * entries from a TITLE.DB file.
 *
 * This version is a bit rushed, as I'm trying to get the exploit out the door
 * and working.
 *
 * The structure of the TITLE.DB file is as follows:
 *
 * <title name>=<exploit>
 * ...
 * ...
 * <payload>
 *
 * Because PS1DRV (see the exploit details) loads TITLE.DB at 0x800000, I've
 * placed the payload start at 0x810110, allowing approx. 64KB worth of
 * exploit data.  This allows for about 197 entries, give or take.
 *
 * This code has bugs.  You shouldn't have any difficulty in finding them.
 */

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if 0
#include "payload.h"
#endif

/* Print an error.  */
#define E_PRINTF(format, args...)	\
	fprintf(stderr, "Error: " format, ## args)

/* Print a string if verbose is at least the specified level.  */
#define V_PRINTF(level, format, args...)	\
	do {					\
		if (verbose >= level)		\
			printf(format, ## args);\
	} while (0)

#define PAYLOAD_OFFSET	0x10110

#define EXPLOIT_OFFSET	304
#define EXPLOIT_SIZE	320
#define EXPLOIT_TOTAL	((TITLE_MAX) + (EXPLOIT_SIZE) + 1 + 1)

#define TITLE_MAX	12
#define MY_FILE_MAX	256

#define LINE_MAX	512

unsigned char exploit_data[EXPLOIT_SIZE];

const char *dbname = "TITLE.DB";

/* Program options.  */
enum options { OPT_NONE, OPT_LIST, OPT_CREATE, OPT_ADD, OPT_DEL };

int progopt = OPT_NONE;
char progname[MY_FILE_MAX + 1];
int verbose = 100;
char outname[MY_FILE_MAX + 1];
char titlename[TITLE_MAX + 1];
char batchname[MY_FILE_MAX + 1];

void print_usage(void);
int parse_options(int argc, char **argv);

void init_exploit_data(void);

int list_title_db(const char *name);
int create_title_db(const char *name);
int del_title_db(FILE *f, const char *title);

#if 0
int process_batch_file(FILE *f, int opt, const char *filename);

int main(int argc, char **argv)
{
	FILE *f;
	int res;

	printf("titleman TITLE.DB manager - version 0.1\n"
		"Copyright (c) 2003  Marcus R. Brown <mrbrown@0xd6.org>\n"
		"Licensed under the Academic Free License version 2.0\n\n");

	if (parse_options(argc, argv) < 0) {
		print_usage();
		return 1;
	}

	switch (progopt) {
		case OPT_CREATE:
			if (create_title_db(outname) < 0)
				return 2;

			break;
		case OPT_LIST:
			if (list_title_db(outname) < 0)
				return 3;

			break;
		case OPT_ADD:
		case OPT_DEL:
			if (!(f = fopen(outname, "rb+"))) {
				E_PRINTF("Unable to open '%s' for writing: %s\n",
						outname, strerror(errno));
				return 4;
			}

			/* Check for a batch file first.  */
			if (*batchname != '\0') {
				if (process_batch_file(f, progopt, batchname) < 0) {
					fclose(f);
					return 5;
				}

				fclose(f);
				break;
			}

			if (progopt == OPT_ADD)
				res = add_title_db(f, titlename);
			else
				res = del_title_db(f, titlename);

			fclose(f);
			if (res < 0)
				return 6;

			break;
	}

	return 0;
}
#endif

void init_exploit_data()
{
	memset(exploit_data, 'X', EXPLOIT_SIZE);
	exploit_data[EXPLOIT_SIZE - 1] = '\0';

	memcpy(exploit_data, "0,0,0,0,0,0,0,0,", 16);

	/* Write the actual exploit (little-endian).  */
	exploit_data[EXPLOIT_OFFSET]     = 0x10;
	exploit_data[EXPLOIT_OFFSET + 1] = 0x01;
	exploit_data[EXPLOIT_OFFSET + 2] = 0x81;
	exploit_data[EXPLOIT_OFFSET + 3] = 0x20;
}

/* Locate the specified title name within the file.  Returns 1 if found and
   0 if not found.  */
int find_title(FILE *f, const char *title, int *offset)
{
	/* The extra byte in TITLE_MAX gives us room for \0.  */
	char line[EXPLOIT_TOTAL + 1];
	int ofs;

	fseek(f, 0, SEEK_SET);

	while (((ofs = ftell(f)) < PAYLOAD_OFFSET) &&
			((fgets(line, EXPLOIT_TOTAL + 1, f) != NULL))) {
		if (!strncmp(line, title, strlen(title))) {
			if (offset)
				*offset = ofs;
			return 1;
		}
	}

	return 0;
}

int get_next_title(FILE *f, char *title, int *offset)
{
	char entry[EXPLOIT_TOTAL + 1];
	char *s = entry;
	int ofs;

	*title = '\0';

	if (((ofs = ftell(f)) < PAYLOAD_OFFSET) &&
			((fgets(entry, EXPLOIT_TOTAL + 1, f) != NULL))) {
		if (*entry != ' ') {
			while (*s != '=')
				s++;

			*s = '\0';
			strncpy(title, entry, TITLE_MAX);

		}

		if (offset)
			*offset = ofs;

		return 1;
	}

	if (offset)
		*offset = ofs;

	return 0;
}

int list_title_db(const char *name)
{
	char title[TITLE_MAX + 1];
	FILE *f;
	int offset, i = 1, free = 0;

	if (!(f = fopen(name, "rb"))) {
		E_PRINTF("Unable to open '%s' for reading:\n", name
			   );
		return -1;
	}

	while (get_next_title(f, title, &offset)) {
		if (*title != '\0')
			printf("(%04d) %s\n", i++, title);
		else
			free++;
	}

	printf("%d entries free.\n", free);
	fclose(f);
	return 0;
}

int add_title_db(const char *name, const char *title)
{
	char t[TITLE_MAX + 1];
	int offset, expsize, i;
	FILE *f;

	// open file for reading
	f = fopen(name, "rb");
	if (!f)
	{
		return -1;
	}

	if (find_title(f, title, &offset)) {
		printf("Warning: Title '%s' already in DB (offset %d), not adding.\n",
				title, offset);
		fclose(f);
		return 0;
	}
	fseek(f, 0, SEEK_SET);

	/* We need to find the first free entry.  */
	while (get_next_title(f, t, &offset)) {
		if (t[0] != '\0') {
			V_PRINTF(2, "Add: Skipping past '%s'.\n", t);
			continue;
		}

		break;
	}

	V_PRINTF(2, "Add: Free entry found at offset '%d'.\n", offset);

	/* (length of title) + '=' + (320-byte exploit) + '\n'  */
	if ((EXPLOIT_TOTAL + offset) > PAYLOAD_OFFSET) {
		E_PRINTF("Add: No room left to insert an entry.\n");
		fclose(f);
		return -1;
	}
	fclose(f);

	// open file for writing
	f = fopen(name, "r+b");
	if (!f)
	{
		return -1;
	}


	if (*exploit_data != '0')
		init_exploit_data();

	V_PRINTF(1, "Adding '%s' to %s... ", title, outname);
	fseek(f, offset, SEEK_SET);
	expsize = fprintf(f, "%s=%s", title, exploit_data);

	/* The entry might be a few bytes shorter than EXPLOIT_TOTAL, so we
	   pad it out with spaces and add '\n' to make it easier on ourselves
	   later.  */
	for (i = 0; i < (EXPLOIT_TOTAL - expsize - 1); i++)
		fputc('X', f);

	fputc('\n', f);
	V_PRINTF(1, "done.\n");

	// seek to end of file
	fseek(f, 0, SEEK_END);

	fclose(f);
	return 0;
}

/* Find the title name and remove the entry.  */
int del_title_db(FILE *f, const char *title)
{
	char entry[EXPLOIT_TOTAL + 1];
	int offset;

	if (!find_title(f, title, &offset)) {
		printf("Warning: Couldn't find entry for title '%s'.\n", title);
		return 0;
	}

	V_PRINTF(2, "Del: Found '%s' at offset %d.\n", title, offset);

	V_PRINTF(1, "Deleting '%s' from %s... ", title, outname);
	memset(entry, ' ', sizeof entry);
	entry[EXPLOIT_TOTAL - 1] = '\n';
	fseek(f, offset, SEEK_SET);
	fwrite(entry, EXPLOIT_TOTAL, 1, f);
	V_PRINTF(1, "done.\n");
	return 0;
}

#if 0
int create_title_db(const char *name)
{
	FILE *f;
	int i, c;

	if (!(f = fopen(name, "wb+"))) {
		E_PRINTF("Unable to open '%s' for writing: %s\n", name,
				strerror(errno));
		return -1;
	}

	for (i = 0; i < PAYLOAD_OFFSET; i++) {
		c = ((i + 1) % EXPLOIT_TOTAL == 0) ?
			'\n' : ' ';
		if (fputc(c, f) == EOF) {
			E_PRINTF("Unable to write to '%s': %s\n", name,
					strerror(errno));
			fclose(f);
			return -1;
		}
	}

	/* Write the payload.  */
	if (!fwrite(binary_data, sizeof binary_data, 1, f)) {
		E_PRINTF("Unable to write to '%s': %s\n", name, strerror(errno));
		fclose(f);
		return -1;
	}

	/* Create the first two "catch-all" entries.  */
	if ((add_title_db(f, "???") < 0) ||
			(add_title_db(f, "PSX.EXE") < 0)) {
		fclose(f);
		return -1;
	}

	fclose(f);
	return 0;
}

int process_batch_file(FILE *f, int opt, const char *filename)
{
	char line[LINE_MAX + 1];
	char title[TITLE_MAX + 1];
	char *t = line, *s;
	FILE *bf;
	int res;

	if (!(bf = fopen(filename, "r"))) {
		E_PRINTF("Unable to open '%s' for reading: %s\n", filename,
				strerror(errno));
		return -1;
	}

	while (fgets(line, LINE_MAX + 1, bf) != NULL) {
		if (*line == ';' || *line == '\n' || *line == '\r')
			continue;

		/* Skip past any leading whitespace.  */
		while (isspace(*t)) {
			if (*t == '\n' || *t == '\0')
				continue;

			t++;
		}

		s = t;
		while (!isspace(*s))
			s++;

		*s = '\0';
		strncpy(title, t, TITLE_MAX);

		if (opt == OPT_ADD)
			res = add_title_db(f, title);
		else
			res = del_title_db(f, title);

		if (res < 0) {
			fclose(bf);
			return -1;
		}
	}

	fclose(bf);
	return 0;
}

void print_usage()
{
	printf("Usage: %s <-c|-a|-d|-l> [@batch file] [title name]\n", progname);
}

int parse_options(int argc, char **argv)
{
	char *option;

	strncpy(progname, argv[0], MY_FILE_MAX);
	strncpy(outname, dbname, MY_FILE_MAX);
	*titlename = '\0';
	*batchname = '\0';

	/* Skip over the program name.  */
	argv++;

	while (--argc > 0) {
		option = argv[0];
		argv++;

		if (option[0] == '-' || option[0] == '/') {
			switch (option[1]) {
				case 'a':	/* Add a title entry.  */
					if (progopt != OPT_NONE)
						goto option_error;
					progopt = OPT_ADD;
					continue;
				case 'c':	/* Create the TITLE.DB file.  */
					if (progopt != OPT_NONE)
						goto option_error;
					progopt = OPT_CREATE;
					continue;
				case 'd':	/* Delete a title entry.  */
					if (progopt != OPT_NONE)
						goto option_error;
					progopt = OPT_DEL;
					continue;
				case 'l':	/* List the contents of TITLE.DB.  */
					if (progopt != OPT_NONE)
						goto option_error;
					progopt = OPT_LIST;
					continue;
				case 'o':	/* Specify output file.  */
					if (!(argc - 1)) {
						E_PRINTF("-o needs a file name.\n");
						return -1;
					}

					strncpy(outname, argv[0], MY_FILE_MAX);
					argv++;
					continue;
				case 'v':	/* Verbose.  */
					verbose++;
					continue;
				default:
					E_PRINTF("unrecognized option: '%c'\n", option[1]);
					return -1;
			}
		}

		/* Process a batch file.  */
		if (option[0] == '@') {
			strncpy(batchname, option + 1, MY_FILE_MAX);
			continue;
		}

		/* Assume it's a title name.  */
		strncpy(titlename, option, TITLE_MAX);
	}

	if (progopt == OPT_NONE) {
		E_PRINTF("At least one of the -l, -c, -a, or -d options must be specified.\n");
		return -1;
	}

	/* -a or -d require a title name or a batch file.  */
	if ((progopt == OPT_ADD || progopt == OPT_DEL) &&
			(*titlename == '\0' && *batchname == '\0')) {
		E_PRINTF("Both the -a (add) or -d (delete) options require a title name.\n");
		return -1;
	}

	return 0;

option_error:
	E_PRINTF("Only one of the -l, -c, -a, or -d options may be specified.\n");
	return -1;
}

#endif

