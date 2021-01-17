/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

// Abstract the details of reading from zip files versus FILE *'s.

#include <string>
#ifdef UNZIP_SUPPORT
#  ifdef SYSTEM_ZIP
#    include <minizip/unzip.h>
#  else
#    include "unzip.h"
#  endif
#endif
#include "snes9x.h"
#include "stream.h"


// Generic constructor/destructor

Stream::Stream (void)
{
	return;
}

Stream::~Stream (void)
{
	return;
}

// Generic getline function, based on gets. Reimlpement if you can do better.

char * Stream::getline (void)
{
	bool		eof;
	std::string	ret;

	ret = getline(eof);
	if (ret.size() == 0 && eof)
		return (NULL);

	return (strdup(ret.c_str()));
}

std::string Stream::getline (bool &eof)
{
	char		buf[1024];
	std::string	ret;

	eof = false;
	ret.clear();

	do
	{
		if (gets(buf, sizeof(buf)) == NULL)
		{
			eof = true;
			break;
		}

		ret.append(buf);
	}
	while (*ret.rbegin() != '\n');

	return (ret);
}

size_t Stream::pos_from_origin_offset(uint8 origin, int32 offset)
{
    size_t position = 0;
    switch (origin)
    {
        case SEEK_SET:
            position = offset;
            break;
        case SEEK_END:
            position = size() + offset;
            break;
        case SEEK_CUR:
            position = pos() + offset;
            break;
    }
    return position;
}

// snes9x.h FSTREAM Stream

fStream::fStream (FSTREAM f)
{
	fp = f;
}

fStream::~fStream (void)
{
	return;
}

int fStream::get_char (void)
{
	return (GETC_FSTREAM(fp));
}

char * fStream::gets (char *buf, size_t len)
{
	return (GETS_FSTREAM(buf, len, fp));
}

size_t fStream::read (void *buf, size_t len)
{
	return (READ_FSTREAM(buf, len, fp));
}

size_t fStream::write (void *buf, size_t len)
{
    return (WRITE_FSTREAM(buf, len, fp));
}

size_t fStream::pos (void)
{
    return (FIND_FSTREAM(fp));
}

size_t fStream::size (void)
{
    size_t sz;
    REVERT_FSTREAM(fp,0L,SEEK_END);
    sz = FIND_FSTREAM(fp);
    REVERT_FSTREAM(fp,0L,SEEK_SET);
    return sz;
}

int fStream::revert (uint8 origin, int32 offset)
{
    return (REVERT_FSTREAM(fp, offset, origin));
}

void fStream::closeStream()
{
    CLOSE_FSTREAM(fp);
    delete this;
}

// unzip Stream

#ifdef UNZIP_SUPPORT

unzStream::unzStream (unzFile &v)
{
	file = v;
    pos_in_buf = 0;
    buf_pos_in_unzipped = unztell(file);
    bytes_in_buf = 0;

    // remember start pos for seeks
    unzGetFilePos(file, &unz_file_start_pos);
}

unzStream::~unzStream (void)
{
	return;
}

size_t unzStream::buffer_remaining()
{
    return bytes_in_buf - pos_in_buf;
}

void unzStream::fill_buffer()
{
    buf_pos_in_unzipped = unztell(file);
    bytes_in_buf = unzReadCurrentFile(file, buffer, unz_BUFFSIZ);
    pos_in_buf = 0;
}

int unzStream::get_char (void)
{
	unsigned char	c;

	if (buffer_remaining() <= 0)
	{
        fill_buffer();
		if (bytes_in_buf <= 0)
			return (EOF);
	}

	c = *(buffer + pos_in_buf);
    pos_in_buf++;

	return ((int) c);
}

char * unzStream::gets (char *buf, size_t len)
{
	size_t	i;
	int		c;

	for (i = 0; i < len - 1; i++)
	{
		c = get_char();
		if (c == EOF)
		{
			if (i == 0)
				return (NULL);
			break;
		}

		buf[i] = (char) c;
		if (buf[i] == '\n')
			break;
	}

	buf[i] = '\0';

	return (buf);
}

size_t unzStream::read (void *buf, size_t len)
{
	if (len == 0)
		return (len);

	size_t	to_read = len;
    uint8 *read_to = (uint8 * )buf;
    do
    {
        size_t in_buffer = buffer_remaining();
        if (to_read <= in_buffer)
        {
            memcpy(read_to, buffer + pos_in_buf, to_read);
            pos_in_buf += to_read;
            to_read = 0;
            break;
        }

        memcpy(read_to, buffer + pos_in_buf, in_buffer);
        to_read -= in_buffer;
        fill_buffer();
    } while (bytes_in_buf);

	return (len - to_read);
}

// not supported
size_t unzStream::write (void *buf, size_t len)
{
    return (0);
}

size_t unzStream::pos (void)
{
    return buf_pos_in_unzipped + pos_in_buf;
}

size_t unzStream::size (void)
{
    unz_file_info	info;
    unzGetCurrentFileInfo(file,&info,NULL,0,NULL,0,NULL,0);
    return info.uncompressed_size;
}

int unzStream::revert (uint8 origin, int32 offset)
{
    size_t target_pos = pos_from_origin_offset(origin, offset);

    // new pos inside buffered data
    if (target_pos >= buf_pos_in_unzipped && target_pos < buf_pos_in_unzipped + bytes_in_buf)
    {
        pos_in_buf = target_pos - buf_pos_in_unzipped;
    }
    else // outside of buffer, reset file and read until pos
    {
        unzGoToFilePos(file, &unz_file_start_pos);
        unzOpenCurrentFile(file); // necessary to reopen after seek
        int times_to_read = target_pos / unz_BUFFSIZ + 1;
        for( int i = 0; i < times_to_read; i++)
        {
            fill_buffer();
        }
        pos_in_buf = target_pos % unz_BUFFSIZ;
    }
    return 0;
}

void unzStream::closeStream()
{
    unzClose(file);
    delete this;
}

#endif

// memory Stream

memStream::memStream (uint8 *source, size_t sourceSize)
{
	mem = head = source;
    msize = remaining = sourceSize;
    readonly = false;
}

memStream::memStream (const uint8 *source, size_t sourceSize)
{
	mem = head = const_cast<uint8 *>(source);
    msize = remaining = sourceSize;
    readonly = true;
}

memStream::~memStream (void)
{
	return;
}

int memStream::get_char (void)
{
    if(!remaining)
        return EOF;

    remaining--;
	return *head++;
}

char * memStream::gets (char *buf, size_t len)
{
    size_t	i;
	int		c;

	for (i = 0; i < len - 1; i++)
	{
		c = get_char();
		if (c == EOF)
		{
			if (i == 0)
				return (NULL);
			break;
		}

		buf[i] = (char) c;
		if (buf[i] == '\n')
			break;
	}

	buf[i] = '\0';

	return (buf);
}

size_t memStream::read (void *buf, size_t len)
{
    size_t bytes = len < remaining ? len : remaining;
    memcpy(buf,head,bytes);
    head += bytes;
    remaining -= bytes;

	return bytes;
}

size_t memStream::write (void *buf, size_t len)
{
    if(readonly)
        return 0;

    size_t bytes = len < remaining ? len : remaining;
    memcpy(head,buf,bytes);
    head += bytes;
    remaining -= bytes;

	return bytes;
}

size_t memStream::pos (void)
{
    return msize - remaining;
}

size_t memStream::size (void)
{
    return msize;
}

int memStream::revert (uint8 origin, int32 offset)
{
    size_t pos = pos_from_origin_offset(origin, offset);

    if(pos > msize)
        return -1;

    head = mem + pos;
    remaining = msize - pos;

    return 0;
}

void memStream::closeStream()
{
    delete [] mem;
    delete this;
}

// dummy Stream

nulStream::nulStream (void)
{
	bytes_written = 0;
}

nulStream::~nulStream (void)
{
	return;
}

int nulStream::get_char (void)
{
    return 0;
}

char * nulStream::gets (char *buf, size_t len)
{
	*buf = '\0';
	return NULL;
}

size_t nulStream::read (void *buf, size_t len)
{
	return 0;
}

size_t nulStream::write (void *buf, size_t len)
{
    bytes_written += len;
	return len;
}

size_t nulStream::pos (void)
{
    return 0;
}

size_t nulStream::size (void)
{
    return bytes_written;
}

int nulStream::revert (uint8 origin, int32 offset)
{
    size_t target_pos = pos_from_origin_offset(origin, offset);
    bytes_written = target_pos;
    return 0;
}

void nulStream::closeStream()
{
    delete this;
}

Stream *openStreamFromFSTREAM(const char* filename, const char* mode)
{
    FSTREAM f = OPEN_FSTREAM(filename,mode);
    if(!f)
        return NULL;
    return new fStream(f);
}

Stream *reopenStreamFromFd(int fd, const char* mode)
{
    FSTREAM f = REOPEN_FSTREAM(fd,mode);
    if(!f)
        return NULL;
    return new fStream(f);
}
