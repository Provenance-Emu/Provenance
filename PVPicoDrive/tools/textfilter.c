#include <stdio.h>
#include <string.h>
#include <ctype.h>


static int check_defines(const char **defs, int defcount, char *tdef)
{
	int i, len;

	while (isspace(*tdef)) tdef++;
	len = strlen(tdef);
	for (i = 0; i < len; i++)
		if (tdef[i] == ' ' || tdef[i] == '\r' || tdef[i] == '\n') break;
	tdef[i] = 0;

	for (i = 0; i < defcount; i++)
	{
		if (strcmp(defs[i], tdef) == 0)
			return 1;
	}

	return 0;
}

static void do_counters(char *str)
{
	static int counter_id = -1, counter;
	char buff[1024];
	char *s = str;

	while ((s = strstr(s, "@@")))
	{
		if (s[2] < '0' || s[2] > '9') { s++; continue; }

		if (counter_id != s[2] - '0') {
			counter_id = s[2] - '0';
			counter = 1;
		}
		snprintf(buff, sizeof(buff), "%i%s", counter++, s + 3);
		strcpy(s, buff);
	}
}

static int my_fputs(char *s, FILE *stream)
{
	char *p;

	for (p = s + strlen(s) - 1; p >= s; p--)
		if (!isspace(*p))
			break;
	p++;

	/* use DOS endings for better viewer compatibility */
	memcpy(p, "\r\n", 3);

	return fputs(s, stream);
}

int main(int argc, char *argv[])
{
	char path[256], path_file[256];
	char buff[1024];
	FILE *fi, *fo;
	int skip_mode = 0, ifdef_level = 0, skip_level = 0, line = 0;
	char *p;

	if (argc < 3)
	{
		printf("usage:\n%s <file_in> <file_out> [defines...]\n", argv[0]);
		return 1;
	}

	fi = fopen(argv[1], "r");
	if (fi == NULL)
	{
		printf("failed to open: %s\n", argv[1]);
		return 2;
	}

	fo = fopen(argv[2], "wb");
	if (fo == NULL)
	{
		printf("failed to open: %s\n", argv[2]);
		return 3;
	}

	snprintf(path, sizeof(path), "%s", argv[1]);
	for (p = path + strlen(path) - 1; p > path; p--) {
		if (*p == '/' || *p == '\\') {
			p[1] = 0;
			break;
		}
	}

	for (++line; !feof(fi); line++)
	{
		char *fgs;

		fgs = fgets(buff, sizeof(buff), fi);
		if (fgs == NULL) break;

		if (buff[0] == '#')
		{
			/* control char */
			if (strncmp(buff, "#ifdef ", 7) == 0)
			{
				ifdef_level++;
				if (!skip_mode && !check_defines((void *) &argv[3], argc-3, buff + 7))
					skip_mode = 1, skip_level = ifdef_level;
			}
			else if (strncmp(buff, "#ifndef ", 8) == 0)
			{
				ifdef_level++;
				if (!skip_mode &&  check_defines((void *) &argv[3], argc-3, buff + 8))
					skip_mode = 1, skip_level = ifdef_level;
			}
			else if (strncmp(buff, "#else", 5) == 0)
			{
				if (!skip_mode || skip_level == ifdef_level)
					skip_mode ^= 1, skip_level = ifdef_level;
			}
			else if (strncmp(buff, "#endif", 6) == 0)
			{
				if (skip_level == ifdef_level)
					skip_mode = 0;
				ifdef_level--;
				if (ifdef_level == 0) skip_mode = 0;
				if (ifdef_level < 0)
				{
					printf("%i: warning: #endif without #ifdef, ignoring\n", line);
					ifdef_level = 0;
				}
			}
			else if (strncmp(buff, "#include ", 9) == 0)
			{
				char *pe, *p = buff + 9;
				FILE *ftmp;
				if (skip_mode)
					continue;
				while (*p && (*p == ' ' || *p == '\"'))
					p++;
				for (pe = p + strlen(p) - 1; pe > p; pe--) {
					if (isspace(*pe) || *pe == '\"') *pe = 0;
					else break;
				}
				snprintf(path_file, sizeof(path_file), "%s%s", path, p);
				ftmp = fopen(path_file, "r");
				if (ftmp == NULL) {
					printf("%i: error: failed to include \"%s\"\n", line, p);
					return 1;
				}
				while (!feof(ftmp))
				{
					fgs = fgets(buff, sizeof(buff), ftmp);
					if (fgs == NULL)
						break;
					my_fputs(buff, fo);
				}
				fclose(ftmp);
				continue;
			}

			/* skip line */
			continue;
		}
		if (!skip_mode)
		{
			do_counters(buff);
			my_fputs(buff, fo);
		}
	}

	fclose(fi);
	fclose(fo);

	return 0;
}

