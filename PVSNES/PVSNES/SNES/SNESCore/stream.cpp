/***********************************************************************************
  Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.

  (c) Copyright 1996 - 2002  Gary Henderson (gary.henderson@ntlworld.com),
                             Jerremy Koot (jkoot@snes9x.com)

  (c) Copyright 2002 - 2004  Matthew Kendora

  (c) Copyright 2002 - 2005  Peter Bortas (peter@bortas.org)

  (c) Copyright 2004 - 2005  Joel Yliluoma (http://iki.fi/bisqwit/)

  (c) Copyright 2001 - 2006  John Weidman (jweidman@slip.net)

  (c) Copyright 2002 - 2006  funkyass (funkyass@spam.shaw.ca),
                             Kris Bleakley (codeviolation@hotmail.com)

  (c) Copyright 2002 - 2010  Brad Jorsch (anomie@users.sourceforge.net),
                             Nach (n-a-c-h@users.sourceforge.net),

  (c) Copyright 2002 - 2011  zones (kasumitokoduck@yahoo.com)

  (c) Copyright 2006 - 2007  nitsuja

  (c) Copyright 2009 - 2011  BearOso,
                             OV2


  BS-X C emulator code
  (c) Copyright 2005 - 2006  Dreamer Nom,
                             zones

  C4 x86 assembler and some C emulation code
  (c) Copyright 2000 - 2003  _Demo_ (_demo_@zsnes.com),
                             Nach,
                             zsKnight (zsknight@zsnes.com)

  C4 C++ code
  (c) Copyright 2003 - 2006  Brad Jorsch,
                             Nach

  DSP-1 emulator code
  (c) Copyright 1998 - 2006  _Demo_,
                             Andreas Naive (andreasnaive@gmail.com),
                             Gary Henderson,
                             Ivar (ivar@snes9x.com),
                             John Weidman,
                             Kris Bleakley,
                             Matthew Kendora,
                             Nach,
                             neviksti (neviksti@hotmail.com)

  DSP-2 emulator code
  (c) Copyright 2003         John Weidman,
                             Kris Bleakley,
                             Lord Nightmare (lord_nightmare@users.sourceforge.net),
                             Matthew Kendora,
                             neviksti

  DSP-3 emulator code
  (c) Copyright 2003 - 2006  John Weidman,
                             Kris Bleakley,
                             Lancer,
                             z80 gaiden

  DSP-4 emulator code
  (c) Copyright 2004 - 2006  Dreamer Nom,
                             John Weidman,
                             Kris Bleakley,
                             Nach,
                             z80 gaiden

  OBC1 emulator code
  (c) Copyright 2001 - 2004  zsKnight,
                             pagefault (pagefault@zsnes.com),
                             Kris Bleakley
                             Ported from x86 assembler to C by sanmaiwashi

  SPC7110 and RTC C++ emulator code used in 1.39-1.51
  (c) Copyright 2002         Matthew Kendora with research by
                             zsKnight,
                             John Weidman,
                             Dark Force

  SPC7110 and RTC C++ emulator code used in 1.52+
  (c) Copyright 2009         byuu,
                             neviksti

  S-DD1 C emulator code
  (c) Copyright 2003         Brad Jorsch with research by
                             Andreas Naive,
                             John Weidman

  S-RTC C emulator code
  (c) Copyright 2001 - 2006  byuu,
                             John Weidman

  ST010 C++ emulator code
  (c) Copyright 2003         Feather,
                             John Weidman,
                             Kris Bleakley,
                             Matthew Kendora

  Super FX x86 assembler emulator code
  (c) Copyright 1998 - 2003  _Demo_,
                             pagefault,
                             zsKnight

  Super FX C emulator code
  (c) Copyright 1997 - 1999  Ivar,
                             Gary Henderson,
                             John Weidman

  Sound emulator code used in 1.5-1.51
  (c) Copyright 1998 - 2003  Brad Martin
  (c) Copyright 1998 - 2006  Charles Bilyue'

  Sound emulator code used in 1.52+
  (c) Copyright 2004 - 2007  Shay Green (gblargg@gmail.com)

  SH assembler code partly based on x86 assembler code
  (c) Copyright 2002 - 2004  Marcus Comstedt (marcus@mc.pp.se)

  2xSaI filter
  (c) Copyright 1999 - 2001  Derek Liauw Kie Fa

  HQ2x, HQ3x, HQ4x filters
  (c) Copyright 2003         Maxim Stepin (maxim@hiend3d.com)

  NTSC filter
  (c) Copyright 2006 - 2007  Shay Green

  GTK+ GUI code
  (c) Copyright 2004 - 2011  BearOso

  Win32 GUI code
  (c) Copyright 2003 - 2006  blip,
                             funkyass,
                             Matthew Kendora,
                             Nach,
                             nitsuja
  (c) Copyright 2009 - 2011  OV2

  Mac OS GUI code
  (c) Copyright 1998 - 2001  John Stiles
  (c) Copyright 2001 - 2011  zones


  Specific ports contains the works of other authors. See headers in
  individual files.


  Snes9x homepage: http://www.snes9x.com/

  Permission to use, copy, modify and/or distribute Snes9x in both binary
  and source form, for non-commercial purposes, is hereby granted without
  fee, providing that this license information and copyright notice appear
  with all copies and any derived work.

  This software is provided 'as-is', without any express or implied
  warranty. In no event shall the authors be held liable for any damages
  arising from the use of this software or it's derivatives.

  Snes9x is freeware for PERSONAL USE only. Commercial users should
  seek permission of the copyright holders first. Commercial use includes,
  but is not limited to, charging money for Snes9x or software derived from
  Snes9x, including Snes9x or derivatives in commercial game bundles, and/or
  using Snes9x as a promotion for your commercial product.

  The copyright holders request that bug fixes and improvements to the code
  should be forwarded to them so everyone can benefit from the modifications
  in future versions.

  Super NES and Super Nintendo Entertainment System are trademarks of
  Nintendo Co., Limited and its subsidiary companies.
 ***********************************************************************************/


// Abstract the details of reading from zip files versus FILE *'s.

#include <string>
#ifdef UNZIP_SUPPORT
#include "unzip.h"
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

int fStream::revert (size_t from, size_t offset)
{
    return (REVERT_FSTREAM(fp, from, offset));
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
	head = NULL;
	numbytes = 0;
}

unzStream::~unzStream (void)
{
	return;
}

int unzStream::get_char (void)
{
	unsigned char	c;

	if (numbytes <= 0)
	{
		numbytes = unzReadCurrentFile(file, buffer, unz_BUFFSIZ);
		if (numbytes <= 0)
			return (EOF);
		head = buffer;
	}

	c = *head;
	head++;
	numbytes--;

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

	if (len <= numbytes)
	{
		memcpy(buf, head, len);
		numbytes -= len;
		head += len;
		return (len);
	}

	size_t	numread = 0;
	if (numbytes > 0)
	{
		memcpy(buf, head, numbytes);
		numread += numbytes;
		head = NULL;
		numbytes = 0;
	}

	int	l = unzReadCurrentFile(file, (uint8 *)buf + numread, len - numread);
	if (l > 0)
		numread += l;

	return (numread);
}

// not supported
size_t unzStream::write (void *buf, size_t len)
{
    return (0);
}

size_t unzStream::pos (void)
{
    return (unztell(file));
}

size_t unzStream::size (void)
{
    unz_file_info	info;
    unzGetCurrentFileInfo(file,&info,NULL,0,NULL,0,NULL,0);
    return info.uncompressed_size;
}

// not supported
int unzStream::revert (size_t from, size_t offset)
{
    return -1;
}

void unzStream::closeStream()
{
    unzCloseCurrentFile(file);
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

int memStream::revert (size_t from, size_t offset)
{
    size_t pos = from + offset;

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

int nulStream::revert (size_t from, size_t offset)
{
    bytes_written = from + offset;
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
