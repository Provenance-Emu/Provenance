#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

FILE *fopen64(const char *filename, const char *type)
{
	return fopen(filename, type);
}

int fseeko64(FILE *stream, int64_t offset, int whence)
{
	return fseek(stream, (long)offset, whence);
}

int64_t ftello64(FILE *stream)
{
	return (int64_t)ftell(stream);
}
