/* seekable zip */

#include "unzip.h"

#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "zlib/zlib.h"


#define errormsg(str1,def,fname) printf("%s: " #def ": " str1 "\n", fname);


/* from gzio.c . Be careful with binary compatibility */
typedef struct gz_stream {
    z_stream stream;
    int      z_err;   /* error code for last stream operation */
    int      z_eof;   /* set if end of input file */
    FILE     *file;   /* .gz file */
    Byte     *inbuf;  /* input buffer */
    Byte     *outbuf; /* output buffer */
    uLong    crc;     /* crc32 of uncompressed data */
    char     *msg;    /* error message */
    char     *path;   /* path name for debugging only */
    int      transparent; /* 1 if input file is not a .gz file */
    char     mode;    /* 'w' or 'r' */
    z_off_t  start;   /* start of compressed data in file (header skipped) */
    z_off_t  in;      /* bytes into deflate or inflate */
    z_off_t  out;     /* bytes out of deflate or inflate */
    int      back;    /* one character push-back */
    int      last;    /* true if push-back is last character */
} gz_stream;

#ifndef Z_BUFSIZE
#  ifdef MAXSEG_64K
#    define Z_BUFSIZE 4096 /* minimize memory usage for 16-bit DOS */
#  else
#    define Z_BUFSIZE 16384
#  endif
#endif
#ifndef Z_PRINTF_BUFSIZE
#  define Z_PRINTF_BUFSIZE 4096
#endif

#define ALLOC(size) malloc(size)

int    destroy      OF((gz_stream *s));


gzFile zip2gz(ZIP* zip, struct zipent* ent)
{
    int err;
    gz_stream *s;
    const char *path;
    int transparent = 0;
    uInt len;

    if (!zip || !ent)
        return NULL;

    /* zip stuff */
    if (ent->compression_method == 0x0000)
    {
        /* file is not compressed, simply stored */

        /* check if size are equal */
        if (ent->compressed_size != ent->uncompressed_size) {
            errormsg("Wrong uncompressed size in store compression", ERROR_CORRUPT,zip->zip);
            return NULL;
        }

        transparent = 1;
    }
    else if (ent->compression_method == 0x0008)
    {
        /* file is compressed using "Deflate" method */
        if (ent->version_needed_to_extract > 0x14) {
            errormsg("Version too new", ERROR_UNSUPPORTED,zip->zip);
            return NULL;
        }

        if (ent->os_needed_to_extract != 0x00) {
            errormsg("OS not supported", ERROR_UNSUPPORTED,zip->zip);
            return NULL;
        }

        if (ent->disk_number_start != zip->number_of_this_disk) {
            errormsg("Cannot span disks", ERROR_UNSUPPORTED,zip->zip);
            return NULL;
        }

    } else {
        errormsg("Compression method unsupported", ERROR_UNSUPPORTED, zip->zip);
        return NULL;
    }

    /* seek to compressed data */
    if (seekcompresszip(zip,ent) != 0) {
        return NULL;
    }

    path = zip->zip;

    /* normal gzip init for read */
    s = (gz_stream *)ALLOC(sizeof(gz_stream));
    if (!s) return Z_NULL;

    s->stream.zalloc = (alloc_func)0;
    s->stream.zfree = (free_func)0;
    s->stream.opaque = (voidpf)0;
    s->stream.next_in = s->inbuf = Z_NULL;
    s->stream.next_out = s->outbuf = Z_NULL;
    s->stream.avail_in = s->stream.avail_out = 0;
    s->file = NULL;
    s->z_err = Z_OK;
    s->z_eof = 0;
    s->in = 0;
    s->out = 0;
    s->back = EOF;
    s->crc = crc32(0L, Z_NULL, 0);
    s->msg = NULL;
    s->transparent = transparent;
    s->mode = 'r';

    s->path = (char*)ALLOC(strlen(path)+1);
    if (s->path == NULL) {
        return destroy(s), (gzFile)Z_NULL;
    }
    strcpy(s->path, path); /* do this early for debugging */

    s->stream.next_in  = s->inbuf = (Byte*)ALLOC(Z_BUFSIZE);

    err = inflateInit2(&(s->stream), -MAX_WBITS);
    /* windowBits is passed < 0 to tell that there is no zlib header.
     * Note that in this case inflate *requires* an extra "dummy" byte
     * after the compressed stream in order to complete decompression and
     * return Z_STREAM_END. Here the gzip CRC32 ensures that 4 bytes are
     * present after the compressed stream.
     */
    if (err != Z_OK || s->inbuf == Z_NULL) {
        return destroy(s), (gzFile)Z_NULL;
    }
    s->stream.avail_out = Z_BUFSIZE;

    errno = 0;
    s->file = zip->fp;
    if (s->file == NULL) {
        return destroy(s), (gzFile)Z_NULL;
    }

    /* check_header(s); */
    errno = 0;
    len = (uInt)fread(s->inbuf, 1, Z_BUFSIZE, s->file);
    if (len == 0 && ferror(s->file)) s->z_err = Z_ERRNO;
    s->stream.avail_in += len;
    s->stream.next_in = s->inbuf;
    if (s->stream.avail_in < 2) {
        return destroy(s), (gzFile)Z_NULL;
    }

    s->start = ftell(s->file) - s->stream.avail_in;

    return (gzFile)s;
}


int gzerror2(gzFile file)
{
    gz_stream *s = (gz_stream*)file;

    if (s == NULL)
        return Z_STREAM_ERROR;

    return s->z_err;
}


