#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ENTRIES_PER_LINE	16

char *remove_directory(char *s)
{
	char *p;
	p = strrchr(s, '\\');
	if (!p) p = strrchr(s, '/');	// remove directory
	if (p) return ++p;
	else return s;
}

int main(int argc, char **argv)
{
	int i;
	char *p, ident[256];

	// print usage if required
	if (argc < 3) {
		printf("Syntax: %s <input.bin> <output.c> [<identifier>]\n", remove_directory(argv[0]));
		return -1;
	}

	// open source bin file
	FILE *fi = fopen(argv[1], "rb");
	if (!fi) {
		printf("Error opening input file!\n");
		return -1;
	}

	// open destination C file
	FILE *fo = fopen(argv[2], "w");
	if (!fo) {
		printf("Error opening output file!\n");
		return -1;
	}

	// copy/generate identifier
	if (argc >= 4) {
		strcpy(ident, argv[3]);
	} else {
		strcpy(ident, remove_directory(argv[1]));
		p = strrchr(ident, '.');	// remove extension too
		if (p) *p = 0;
	}

	// convert data
	fprintf(fo, "const unsigned char %s[] =\n{\n", ident);
	while (!feof(fi)) {
		for (i=0; i<ENTRIES_PER_LINE; i++) {
			int c = fgetc(fi);
			if (c < 0) break;
			if (i == 0) fprintf(fo, "\t");
			fprintf(fo, "0x%02X,", c);
		}
		if (i) fprintf(fo, "\n");
	}
	fprintf(fo, "};\n");

	// close files and exit
	fclose(fi);
	fclose(fo);
	return 0;
}
