/*

Copyright (c) 2011, 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 */

#ifndef LHASA_PUBLIC_LHA_FILE_HEADER_H
#define LHASA_PUBLIC_LHA_FILE_HEADER_H

#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @file lha_file_header.h
 *
 * @brief LHA file header structure.
 *
 * This file contains the definition of the @ref LHAFileHeader structure,
 * representing a decoded file header from an LZH file.
 */

/** OS type value for an unknown OS. */
#define LHA_OS_TYPE_UNKNOWN            0x00
/** OS type value for Microsoft MS/DOS. */
#define LHA_OS_TYPE_MSDOS              'M'
/** OS type value for Microsoft Windows 95. */
#define LHA_OS_TYPE_WIN95              'w'
/** OS type value for Microsoft Windows NT. */
#define LHA_OS_TYPE_WINNT              'W'
/** OS type value for Unix. */
#define LHA_OS_TYPE_UNIX               'U'
/** OS type value for IBM OS/2. */
#define LHA_OS_TYPE_OS2                '2'
/** OS type for Apple Mac OS (Classic). */
#define LHA_OS_TYPE_MACOS              'm'
/** OS type for Amiga OS. */
#define LHA_OS_TYPE_AMIGA              'A'
/** OS type for Atari TOS. */
#define LHA_OS_TYPE_ATARI              'a'

// Obscure:

/** OS type for Sun (Oracle) Java. */
#define LHA_OS_TYPE_JAVA               'J'
/** OS type for Digital Research CP/M. */
#define LHA_OS_TYPE_CPM                'C'
/** OS type for Digital Research FlexOS. */
#define LHA_OS_TYPE_FLEX               'F'
/** OS type for Runser (?). */
#define LHA_OS_TYPE_RUNSER             'R'
/** OS type for Fujitsu FM Towns OS. */
#define LHA_OS_TYPE_TOWNSOS            'T'
/** OS type for Microware OS-9. */
#define LHA_OS_TYPE_OS9                '9'
/** OS type for Microware OS-9/68k. */
#define LHA_OS_TYPE_OS9_68K            'K'
/** OS type for OS/386 (?). */
#define LHA_OS_TYPE_OS386              '3'
/** OS type for Sharp X68000 Human68K OS. */
#define LHA_OS_TYPE_HUMAN68K           'H'
/** "OS type" that is used by the LHARK tool and does not indicate an
    OS as such, except that LHARK only runs under DOS. */
#define LHA_OS_TYPE_LHARK              ' '

/**
 * Compression type for a stored directory. The same value is also
 * used for Unix symbolic links.
 */
#define LHA_COMPRESS_TYPE_DIR   "-lhd-"

/**
 * Bit field value set in extra_flags to indicate that the
 * Unix file permission header (0x50) was parsed.
 */
#define LHA_FILE_UNIX_PERMS            0x01

/**
 * Bit field value set in extra_flags to indicate that the
 * Unix UID/GID header (0x51) was parsed.
 */
#define LHA_FILE_UNIX_UID_GID          0x02

/**
 * Bit field value set in extra_flags to indicate that the 'common
 * header' extended header (0x00) was parsed, and the common_crc
 * field has been set.
 */
#define LHA_FILE_COMMON_CRC            0x04

/**
 * Bit field value set in extra_flags to indicate that the
 * Windows time stamp header (0x41) was parsed, and the Windows
 * FILETIME timestamp fields have been set.
 */
#define LHA_FILE_WINDOWS_TIMESTAMPS    0x08

/**
 * Bit field value set in extra_flags to indicate that the OS-9
 * permissions field is set.
 */
#define LHA_FILE_OS9_PERMS             0x10

typedef struct _LHAFileHeader LHAFileHeader;

#define LHA_FILE_HAVE_EXTRA(header, flag) \
	(((header)->extra_flags & (flag)) != 0)
/**
 * Structure containing a decoded LZH file header.
 *
 * A file header precedes the compressed data of each file stored
 * within an LZH archive. It contains the name of the file, and
 * various additional metadata, some of which is optional, and
 * can depend on the header format, the tool used to create the
 * archive, and the operating system on which it was created.
 */

struct _LHAFileHeader {

	// Internal fields, do not touch!

	unsigned int _refcount;
	LHAFileHeader *_next;

	/**
	 * Stored path, with Unix-style ('/') path separators.
	 *
	 * This may be NULL, although if this is a directory
	 * (@ref LHA_COMPRESS_TYPE_DIR), it is never NULL.
	 */
	char *path;

	/**
	 * File name.
	 *
	 * This is never NULL, except if this is a directory
	 * (@ref LHA_COMPRESS_TYPE_DIR), where it is always NULL.
	 */
	char *filename;

	/**
	 * Target for symbolic link.
	 *
	 * This is NULL unless this header represents a symbolic link
	 * (@ref LHA_COMPRESS_TYPE_DIR).
	 */
	char *symlink_target;

	/**
	 * Compression method.
	 *
	 * If the header represents a directory or a symbolic link, the
	 * compression method is equal to @ref LHA_COMPRESS_TYPE_DIR.
	 */
	char compress_method[6];

	/** Length of the compressed data. */
	size_t compressed_length;

	/** Length of the uncompressed data. */
	size_t length;

	/** LZH header format used to store this header. */
	uint8_t header_level;

	/**
	 * OS type indicator, identifying the OS on which
	 * the archive was created.
	 */
	uint8_t os_type;

	/** 16-bit CRC of the compressed data. */
	uint16_t crc;

	/** Unix timestamp of the modification time of the file. */
	unsigned int timestamp;

	/** Pointer to a buffer containing the raw header data. */
	uint8_t *raw_data;

	/** Length of the raw header data. */
	size_t raw_data_len;

	/**
	 * Flags bitfield identifying extra data decoded from extended
	 * headers.
	 */
	unsigned int extra_flags;

	/** Unix permissions, set if @ref LHA_FILE_UNIX_PERMS is set. */
	unsigned int unix_perms;

	/** Unix user ID, set if @ref LHA_FILE_UNIX_UID_GID is set. */
	unsigned int unix_uid;

	/** Unix group ID, set if @ref LHA_FILE_UNIX_UID_GID is set. */
	unsigned int unix_gid;

	/** OS-9 permissions, set if @ref LHA_FILE_OS9_PERMS is set. */
	unsigned int os9_perms;

	/** Unix username. */
	char *unix_username;

	/** Unix group name. */
	char *unix_group;

	/** 16-bit CRC of header contents. */
	uint16_t common_crc;

	/**
	 * Windows FILETIME file creation time, set if
	 * @ref LHA_FILE_WINDOWS_TIMESTAMPS is set.
	 */
	uint64_t win_creation_time;

	/**
	 * Windows FILETIME file modification time, set if
	 * @ref LHA_FILE_WINDOWS_TIMESTAMPS is set.
	 */
	uint64_t win_modification_time;

	/**
	 * Windows FILETIME file access time, set if
	 * @ref LHA_FILE_WINDOWS_TIMESTAMPS is set.
	 */
	uint64_t win_access_time;
};

#ifdef __cplusplus
}
#endif

#endif /* #ifndef LHASA_PUBLIC_LHA_FILE_HEADER_H */
