#include <zlib.h>
#include <stdio.h>

/* Macros taken from gzip source to read header values */
static int gzmagic[2] = {0x1f, 0x8b};
#define SH(p) ((unsigned short)(unsigned char)((p)[0]) | ((unsigned short)(unsigned char)((p)[1]) << 8))
#define LG(p) ((unsigned long)(SH(p)) | ((unsigned long)(SH((p)+2)) << 16))

/* will verify it is a valid gzip file
 * BTW, this is a severely hacked down version of the one in gzio.c
 * returns 0 if successful, 1 if not
 */
int check_header(file_t f)
{
    unsigned char i, c, method, flags;
    
    /* Check the gzip magic header */
    for (i = 0; i < 2; i++)
    {
        fs_read(f,&c,1);
        if (c != gzmagic[i])
            return 1;
    }

    fs_read(f,&method,1);
    fs_read(f,&flags,1);

    if (method != Z_DEFLATED || (flags & 0xE0) != 0)
        return 1;

    return 0;
}

int zlib_getlength(char *filename)
{
  char temp[4];
  file_t f;

  f = fs_open(filename, O_RDONLY);
  if (!f)
    return 0;
  if (check_header(f))
  {
    size_t length;
    length = fs_total(f);
    fs_close(f);
    return length;
  }
  fs_seek(f, -4, SEEK_END);
  fs_read(f, temp, 4);
  fs_close(f);
  return LG(temp);
} 

