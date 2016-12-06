#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

#define OUT_FILE "PicoAll.c"

// files to amalgamate, in order
static const char *files[] =
{
	"Pico/Pico.h",
	// PicoInt.h includes some CD stuff, so start with them
	"Pico/cd/cd_file.h",
	"Pico/cd/cd_sys.h",
	"Pico/cd/LC89510.h",
	"Pico/cd/gfx_cd.h",
	"Pico/cd/pcm.h",
	"Pico/PicoInt.h",
	"Pico/Patch.h",
	"Pico/sound/mix.h",
	// source
	"Pico/Area.c",
	"Pico/Cart.c",
	"Pico/Draw2.c",
	"Pico/Draw.c",
	"Pico/VideoPort.c",
	"Pico/sound/sound.c",
	"Pico/MemoryCmn.c",
	"Pico/Memory.c",
	"Pico/Misc.c",
	"Pico/Patch.c",
	"Pico/Sek.c",
	"Pico/cd/Area.c",
	"Pico/cd/buffering.c",
	"Pico/cd/cd_file.c",
	"Pico/cd/cd_sys.c",
	"Pico/cd/cell_map.c",
	"Pico/cd/gfx_cd.c",
	"Pico/cd/LC89510.c",
	"Pico/cd/Memory.c",
	"Pico/cd/Misc.c",
	"Pico/cd/pcm.c",
	"Pico/cd/Sek.c",
	"Pico/cd/Pico.c",
	"Pico/Pico.c",
};

static char *includes[128];

static void eprintf(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	vprintf(fmt, args);
	va_end(args);

	exit(1);
}

static void emit_header(FILE *f, const char *fname)
{
	char tmp[128] = "/*                                                            */";
	memcpy(tmp + 3, fname, strlen(fname));
	fprintf(f, "\n\n");
	fprintf(f, "/**************************************************************/\n");
	fprintf(f, "/**************************************************************/\n");
	fprintf(f, "%s\n", tmp);
	fprintf(f, "/**************************************************************/\n");
}

static const char *add_include(const char *include)
{
	int i;
	char processed_inc[128+4];

	// must first quote relative includes
	snprintf(processed_inc, sizeof(processed_inc), (include[0] != '<') ? "\"%s\"" : "%s", include);

	// find in include list
	for (i = 0; includes[i] && i < 128; i++)
	{
		if (strcmp(processed_inc, includes[i]) == 0) break;
	}
	if (i == 128) eprintf("add_include: includes overflowed\n");
	if (includes[i] != NULL)
	{
		printf("already have: %s\n", processed_inc);
		return NULL;
	}
	else
	{
		printf("adding: %s\n", processed_inc);
		includes[i] = strdup(processed_inc);
		if (includes[i] == NULL) eprintf("add_include: OOM\n");
		return includes[i];
	}
}

static const char *add_raw_include(const char *include, const char *base)
{
	const char *ps, *pe;
	char processed_inc[128];

	for (ps = include; *ps && isspace(*ps); ps++);

	if (*ps == '<')
	{
		int len = 1;
		// system include, search for '>'
		for (pe = ps; *pe && *pe != '>'; pe++, len++);
		if (*pe == 0 || len > 127) eprintf("add_raw_include: failed sysinclude, len=%i\n", len);
		strncpy(processed_inc, ps, len);
		processed_inc[len] = 0;
	}
	else if (*ps == '\"')
	{
		int len, pos;
		// relative include, make path absolute (or relative to base dir)
		strcpy(processed_inc, base);
		ps++;
		while (*ps == '.')
		{
			if (strncmp(ps, "../", 3) == 0)
			{
				char *p;
				if (processed_inc[0] == 0)
					eprintf("add_raw_include: already in root, can't go down: %s | %s\n", ps, include);
				p = strrchr(processed_inc, '/');
				if (p == NULL) eprintf("add_raw_include: can't happen\n");
				*p = 0;
				p = strrchr(processed_inc, '/');
				if (p != NULL) p[1] = 0;
				else processed_inc[0] = 0;
				ps += 3;
			}
			else if (strncmp(ps, "./", 2) == 0)
			{
				ps += 2; // just skip
			}
			while (*ps == '/') ps++;
		}
		if (*ps == 0) eprintf("add_raw_include: failed with %s\n", include);

		len = pos = strlen(processed_inc);
		for (pe = ps; *pe && *pe != '\"'; pe++, len++);
		if (*pe == 0 || len > 127) eprintf("add_raw_include: failed with %s, len=%i\n", include, len);
		strncpy(processed_inc + pos, ps, len - pos);
		processed_inc[len] = 0;
	}
	else
		eprintf("add_raw_include: unhandled include: %s\n", ps);

	return add_include(processed_inc);
}

// returns pointer to location after part in string
static const char *substr_end(const char *string, const char *part)
{
	const char *p = string;
	int len = strlen(part);

	while (*p && isspace(*p)) p++;
	return (strncmp(p, part, len) == 0) ? (p + len) : NULL;
}

static void strip_cr(char *str)
{
	int len = strlen(str);
	char *p = str;

	while ((p = strchr(p, '\r')))
	{
		memmove(p, p + 1, len - (p - str) + 1);
	}
	if (strlen(str) > 0)
	{
		p = str + strlen(str) - 1;
		while (p >= str && isspace(*p)) { *p = 0; p--; } // strip spaces on line ends
	}
	strcat(str, "\n"); // re-add newline
}

int main(void)
{
	char buff[512]; // tmp buffer
	char path[128]; // path to file being included, with ending slash
	int i, ifile;
	FILE *fo;

	memset(includes, 0, sizeof(includes));

	fo = fopen(OUT_FILE, "w");
	if (fo == NULL) return 1;

	// special header
	fprintf(fo, "#define PICO_INTERNAL static\n");
	fprintf(fo, "#define PICO_INTERNAL_ASM\n");

	for (ifile = 0; ifile < sizeof(files) / sizeof(files[0]); ifile++)
	{
		FILE *fi;
		const char *file = files[ifile], *p;
		p = strrchr(file, '/');
		if (p == NULL) eprintf("main: file in root? %s\n", file);
		strncpy(path, file, p - file + 1);
		path[p - file + 1] = 0;

		fi = fopen(file, "r");
		if (fi == NULL) eprintf("main: failed to open %s\n", file);

		// if (strcmp(file + strlen(file) - 2, ".h") == 0)
		add_include(file);
		emit_header(fo, file);

		while (!feof(fi))
		{
			p = fgets(buff, sizeof(buff), fi);
			if (p == NULL) break;
			strip_cr(buff);
			// include?
			p = substr_end(buff, "#include");
			if (p != NULL)
			{
				p = add_raw_include(p, path);
				if (p != NULL) fprintf(fo, "#include %s\n", p);
				continue;
			}
			// passthrough
			fputs(buff, fo);
		}
	}

	emit_header(fo, "EOF");

	for (i = 0; includes[i] && i < 128; i++)
	{
		free(includes[i]);
	}

	fclose(fo);

	return 0;
}

