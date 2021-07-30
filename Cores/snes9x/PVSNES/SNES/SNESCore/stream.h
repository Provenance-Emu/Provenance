/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _STREAM_H_
#define _STREAM_H_

#include <string>

class Stream
{
	public:
		Stream (void);
		virtual ~Stream (void);
		virtual int get_char (void) = 0;
		virtual char * gets (char *, size_t) = 0;
		virtual char * getline (void);	// free() when done
		virtual std::string getline (bool &);
		virtual size_t read (void *, size_t) = 0;
        virtual size_t write (void *, size_t) = 0;
        virtual size_t pos (void) = 0;
        virtual size_t size (void) = 0;
        virtual int revert (uint8 origin, int32 offset) = 0;
        virtual void closeStream() = 0;

	protected:
		size_t pos_from_origin_offset(uint8 origin, int32 offset);
};

class fStream : public Stream
{
	public:
		fStream (FSTREAM);
		virtual ~fStream (void);
		virtual int get_char (void);
		virtual char * gets (char *, size_t);
		virtual size_t read (void *, size_t);
        virtual size_t write (void *, size_t);
        virtual size_t pos (void);
        virtual size_t size (void);
        virtual int revert (uint8 origin, int32 offset);
        virtual void closeStream();

	private:
		FSTREAM	fp;
};

#ifdef UNZIP_SUPPORT
#  ifdef SYSTEM_ZIP
#    include <minizip/unzip.h>
#  else
#    include "unzip.h"
#  endif

#define unz_BUFFSIZ	1024

class unzStream : public Stream
{
	public:
		unzStream (unzFile &);
		virtual ~unzStream (void);
		virtual int get_char (void);
		virtual char * gets (char *, size_t);
		virtual size_t read (void *, size_t);
        virtual size_t write (void *, size_t);
        virtual size_t pos (void);
        virtual size_t size (void);
        virtual int revert (uint8 origin, int32 offset);
        virtual void closeStream();

	private:
        void   fill_buffer();
        size_t buffer_remaining();

		unzFile	file;
		char	buffer[unz_BUFFSIZ];
        size_t  pos_in_buf;
        size_t  buf_pos_in_unzipped;
		size_t	bytes_in_buf;
        unz_file_pos unz_file_start_pos;
};

#endif

class memStream : public Stream
{
	public:
        memStream (uint8 *,size_t);
        memStream (const uint8 *,size_t);
		virtual ~memStream (void);
		virtual int get_char (void);
		virtual char * gets (char *, size_t);
		virtual size_t read (void *, size_t);
        virtual size_t write (void *, size_t);
        virtual size_t pos (void);
        virtual size_t size (void);
        virtual int revert (uint8 origin, int32 offset);
        virtual void closeStream();

	private:
		uint8   *mem;
        size_t  msize;
        size_t  remaining;
		uint8	*head;
        bool    readonly;
};

/* dummy stream that always reads 0 and writes nowhere
   but counts bytes written
*/
class nulStream : public Stream
{
	public:
        nulStream (void);
		virtual ~nulStream (void);
        virtual int get_char (void);
        virtual char * gets (char *, size_t);
		virtual size_t read (void *, size_t);
        virtual size_t write (void *, size_t);
        virtual size_t pos (void);
        virtual size_t size (void);
        virtual int revert (uint8 origin, int32 offset);
        virtual void closeStream();

    private:
        size_t  bytes_written;
};

Stream *openStreamFromFSTREAM(const char* filename, const char* mode);
Stream *reopenStreamFromFd(int fd, const char* mode);


#endif
