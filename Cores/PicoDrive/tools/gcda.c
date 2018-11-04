#include <stdio.h>
//#include <stdlib.h>
#include <string.h>
#include <unistd.h>


static int search_gcda(const char *str, int len)
{
	int i;
	for (i = 0; i < len - 6; i++)
		if (str[i]   == '.' && str[i+1] == 'g' && str[i+2] == 'c' &&
		    str[i+3] == 'd' && str[i+4] == 'a' && str[i+5] == 0)
			return i;
	return -1;
}

static int is_good_char(char c)
{
	return c >= ' ' && c < 0x7f;
}

static int is_good_path(char *path)
{
	int len = strlen(path);

	path[len-2] = 'n';
	path[len-1] = 'o';

	FILE *f = fopen(path, "rb");

	path[len-2] = 'd';
	path[len-1] = 'a';

	if (f) {
		fclose(f);
		return 1;
	}
	printf("not good path: %s\n", path);
	return 0;
}

int main(int argc, char *argv[])
{
	char buff[1024], *p;
	char cwd[4096];
	FILE *f;
	int l, pos, pos1, old_len, cwd_len;

	if (argc != 2) return 1;

	getcwd(cwd, sizeof(cwd));
	cwd_len = strlen(cwd);
	if (cwd[cwd_len-1] != '/') {
		cwd[cwd_len++] = '/';
		cwd[cwd_len] = 0;
	}

	f = fopen(argv[1], "rb+");
	if (f == NULL) return 2;

	while (1)
	{
readnext:
		l = fread(buff, 1, sizeof(buff), f);
		if (l <= 16) break;

		pos = 0;
		while (pos < l)
		{
			pos1 = search_gcda(buff + pos, l - pos);
			if (pos1 < 0) {
				fseek(f, -6, SEEK_CUR);
				goto readnext;
			}
			pos += pos1;

			while (pos > 0 && is_good_char(buff[pos-1])) pos--;

			if (pos == 0) {
				fseek(f, -(sizeof(buff) + 16), SEEK_CUR);
				goto readnext;
			}

			// paths must start with /
			while (pos < l && buff[pos] != '/') pos++;
			p = buff + pos;
			old_len = strlen(p);

			if (!is_good_path(p)) {
				pos += old_len;
				continue;
			}

			if (strncmp(p, cwd, cwd_len) != 0) {
				printf("can't handle: %s\n", p);
				pos += old_len;
				continue;
			}

			memmove(p, p + cwd_len, old_len - cwd_len + 1);
			fseek(f, -(sizeof(buff) - pos), SEEK_CUR);
			fwrite(p, 1, old_len, f);
			goto readnext;
		}
	}

	fclose(f);

	return 0;
}

