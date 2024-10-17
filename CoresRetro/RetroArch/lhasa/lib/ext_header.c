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

#include <stdlib.h>
#include <string.h>

#include "ext_header.h"
#include "lha_endian.h"

//
// Extended header parsing.
//
// Extended headers were introduced with LHA v2 - various different
// tools support different extended headers. Some are operating system
// specific.
//

// Extended header types:

#define LHA_EXT_HEADER_COMMON              0x00
#define LHA_EXT_HEADER_FILENAME            0x01
#define LHA_EXT_HEADER_PATH                0x02
#define LHA_EXT_HEADER_MULTI_DISC          0x39
#define LHA_EXT_HEADER_COMMENT             0x3f

#define LHA_EXT_HEADER_WINDOWS_TIMESTAMPS  0x41

#define LHA_EXT_HEADER_UNIX_PERMISSION     0x50
#define LHA_EXT_HEADER_UNIX_UID_GID        0x51
#define LHA_EXT_HEADER_UNIX_GROUP          0x52
#define LHA_EXT_HEADER_UNIX_USER           0x53
#define LHA_EXT_HEADER_UNIX_TIMESTAMP      0x54

#define LHA_EXT_HEADER_OS9                 0xcc

/**
 * Structure representing an extended header type.
 */
typedef struct {

	/**
	 * Header number.
	 *
	 * Each extended header type has a unique byte value that represents
	 * it.
	 */
	uint8_t num;

	/**
	 * Callback function for parsing an extended header block.
	 *
	 * @param header     The file header structure in which to store
	 *                   decoded data.
	 * @param data       Pointer to the header data to decode.
	 * @param data_len   Size of the header data, in bytes.
	 * @return           Non-zero if successful, or zero for failure.
	 */
	int (*decoder)(LHAFileHeader *header, uint8_t *data, size_t data_len);

	/** Minimum length for a header of this type. */
	size_t min_len;

} LHAExtHeaderType;

// Common header (0x00).
//
// This contains a 16-bit CRC of the entire LHA header.

static int ext_header_common_decoder(LHAFileHeader *header,
                                     uint8_t *data,
                                     size_t data_len)
{
	header->extra_flags |= LHA_FILE_COMMON_CRC;
	header->common_crc = lha_decode_uint16(data);

	// There is a catch-22 in calculating the CRC, because the field
	// containing the CRC is part of the data being CRC'd. The solution
	// is that the CRC is calculated with the CRC field set to zero.
	// Therefore, now that the CRC has been read, set the field to
	// zero in the raw_data array so that the CRC can be calculated
	// correctly.

	data[0] = 0x00;
	data[1] = 0x00;

	// TODO: Some platforms (OS/2, Unix) put extra data in the common
	// header which might also be decoded.

	return 1;
}

static LHAExtHeaderType lha_ext_header_common = {
	LHA_EXT_HEADER_COMMON,
	ext_header_common_decoder,
	2
};

// Filename header (0x01).
//
// This stores the filename for the file. This is essential on level 2/3
// headers, as the filename field is no longer part of the standard
// header.

static int ext_header_filename_decoder(LHAFileHeader *header,
                                       uint8_t *data,
                                       size_t data_len)
{
	char *new_filename;
	unsigned int i;

	new_filename = malloc(data_len + 1);

	if (new_filename == NULL) {
		return 0;
	}

	memcpy(new_filename, data, data_len);
	new_filename[data_len] = '\0';

	// Sanitize the filename that was read. It is not allowed to
	// contain a path separator, which could potentially be used
	// to do something malicious.

	for (i = 0; new_filename[i] != '\0'; ++i) {
		if (new_filename[i] == '/') {
			new_filename[i] = '_';
		}
	}

	free(header->filename);
	header->filename = new_filename;

	return 1;
}

static LHAExtHeaderType lha_ext_header_filename = {
	LHA_EXT_HEADER_FILENAME,
	ext_header_filename_decoder,
	1
};

// Path header (0x02).
//
// This stores the directory path of the file. A value of 0xff is used
// as the path separator. It is supposed to include a terminating path
// separator as the last character.

static int ext_header_path_decoder(LHAFileHeader *header,
                                   uint8_t *data,
                                   size_t data_len)
{
	unsigned int i;
	uint8_t *new_path;

	new_path = malloc(data_len + 2);

	if (new_path == NULL) {
		return 0;
	}

	memcpy(new_path, data, data_len);
	new_path[data_len] = '\0';

	// Amiga LHA v1.22 generates path headers without a path
	// separator at the end of the string. This is broken (and
	// was fixed in a later version), but handle it correctly.

	if (new_path[data_len - 1] != 0xff) {
		new_path[data_len] = 0xff;
		new_path[data_len + 1] = '\0';
		++data_len;
	}

	free(header->path);
	header->path = (char *) new_path;

	for (i = 0; i < data_len; ++i) {
		if (new_path[i] == 0xff) {
			new_path[i] = '/';
		}
	}

	return 1;
}

static LHAExtHeaderType lha_ext_header_path = {
	LHA_EXT_HEADER_PATH,
	ext_header_path_decoder,
	1
};

// Windows timestamp header (0x41).
//
// This is a Windows-specific header that stores 64-bit timestamps in
// Windows FILETIME format. The timestamps have 100ns accuracy, which is
// much more accurate than the normal Unix time_t format.

static int ext_header_windows_timestamps(LHAFileHeader *header,
                                         uint8_t *data,
                                         size_t data_len)
{
	header->extra_flags |= LHA_FILE_WINDOWS_TIMESTAMPS;
	header->win_creation_time = lha_decode_uint64(data);
	header->win_modification_time = lha_decode_uint64(data + 8);
	header->win_access_time = lha_decode_uint64(data + 16);

	return 1;
}

static LHAExtHeaderType lha_ext_header_windows_timestamps = {
	LHA_EXT_HEADER_WINDOWS_TIMESTAMPS,
	ext_header_windows_timestamps,
	24
};


// Unix permissions header (0x50).

static int ext_header_unix_perms_decoder(LHAFileHeader *header,
                                         uint8_t *data,
                                         size_t data_len)
{
	header->extra_flags |= LHA_FILE_UNIX_PERMS;
	header->unix_perms = lha_decode_uint16(data);

	return 1;
}

static LHAExtHeaderType lha_ext_header_unix_perms = {
	LHA_EXT_HEADER_UNIX_PERMISSION,
	ext_header_unix_perms_decoder,
	2
};

// Unix UID/GID header (0x51).

static int ext_header_unix_uid_gid_decoder(LHAFileHeader *header,
                                           uint8_t *data,
                                           size_t data_len)
{
	header->extra_flags |= LHA_FILE_UNIX_UID_GID;
	header->unix_gid = lha_decode_uint16(data);
	header->unix_uid = lha_decode_uint16(data + 2);

	return 1;
}

static LHAExtHeaderType lha_ext_header_unix_uid_gid = {
	LHA_EXT_HEADER_UNIX_UID_GID,
	ext_header_unix_uid_gid_decoder,
	4
};

// Unix username header (0x53).
//
// This stores a string containing the username. There don't seem to be
// any tools that actually generate archives containing this header.

static int ext_header_unix_username_decoder(LHAFileHeader *header,
                                            uint8_t *data,
                                            size_t data_len)
{
	char *username;

	username = malloc(data_len + 1);

	if (username == NULL) {
		return 0;
	}

	memcpy(username, data, data_len);
	username[data_len] = '\0';

	free(header->unix_username);
	header->unix_username = username;

	return 1;
}

static LHAExtHeaderType lha_ext_header_unix_username = {
	LHA_EXT_HEADER_UNIX_USER,
	ext_header_unix_username_decoder,
	1
};

// Unix group header (0x52).
//
// This stores a string containing the Unix group name. As with the
// username header, there don't seem to be  any tools that actually
// generate archives containing this header.

static int ext_header_unix_group_decoder(LHAFileHeader *header,
                                         uint8_t *data,
                                         size_t data_len)
{
	char *group;

	group = malloc(data_len + 1);

	if (group == NULL) {
		return 0;
	}

	memcpy(group, data, data_len);
	group[data_len] = '\0';

	free(header->unix_group);
	header->unix_group = group;

	return 1;
}

static LHAExtHeaderType lha_ext_header_unix_group = {
	LHA_EXT_HEADER_UNIX_GROUP,
	ext_header_unix_group_decoder,
	1
};

// Unix timestamp header (0x54).
//
// This stores a 32-bit Unix time_t timestamp representing the
// modification time of the file.

static int ext_header_unix_timestamp_decoder(LHAFileHeader *header,
                                             uint8_t *data,
                                             size_t data_len)
{
	header->timestamp = lha_decode_uint32(data);

	return 1;
}

static LHAExtHeaderType lha_ext_header_unix_timestamp = {
	LHA_EXT_HEADER_UNIX_TIMESTAMP,
	ext_header_unix_timestamp_decoder,
	4
};

// OS-9 (6809) header (0xcc)
//
// This stores OS-9 filesystem metadata.

static int ext_header_os9_decoder(LHAFileHeader *header,
                                  uint8_t *data,
                                  size_t data_len)
{
	// TODO: The OS-9 extended header contains various data, but
	// it's not clear what it's all for. Just extract the
	// permissions for now.

	header->os9_perms = lha_decode_uint16(data + 7);
	header->extra_flags |= LHA_FILE_OS9_PERMS;

	return 1;
}

static LHAExtHeaderType lha_ext_header_os9 = {
	LHA_EXT_HEADER_OS9,
	ext_header_os9_decoder,
	12
};

// Table of extended headers.

static const LHAExtHeaderType *ext_header_types[] = {
	&lha_ext_header_common,
	&lha_ext_header_filename,
	&lha_ext_header_path,
	&lha_ext_header_unix_perms,
	&lha_ext_header_unix_uid_gid,
	&lha_ext_header_unix_username,
	&lha_ext_header_unix_group,
	&lha_ext_header_unix_timestamp,
	&lha_ext_header_windows_timestamps,
	&lha_ext_header_os9,
};

#define NUM_HEADER_TYPES (sizeof(ext_header_types) / sizeof(*ext_header_types))

/**
 * Look up the extended header parser for the specified header code.
 *
 * @param num       Extended header type.
 * @return          Matching @ref LHAExtHeaderType structure, or NULL if
 *                  not found for this header type.
 */

static const LHAExtHeaderType *ext_header_for_num(uint8_t num)
{
	unsigned int i;

	for (i = 0; i < NUM_HEADER_TYPES; ++i) {
		if (ext_header_types[i]->num == num) {
			return ext_header_types[i];
		}
	}

	return NULL;
}

int lha_ext_header_decode(LHAFileHeader *header,
                          uint8_t num,
                          uint8_t *data,
                          size_t data_len)
{
	const LHAExtHeaderType *htype;

	htype = ext_header_for_num(num);

	if (htype == NULL) {
		return 0;
	}

	if (data_len < htype->min_len) {
		return 0;
	}

	return htype->decoder(header, data, data_len);
}
