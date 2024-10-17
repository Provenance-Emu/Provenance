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
#include <ctype.h>
#include <time.h>

#include "lha_endian.h"
#include "lha_file_header.h"
#include "ext_header.h"
#include "crc16.h"

#define COMMON_HEADER_LEN 22 /* bytes */

// Minimum length of a level 0 header (with zero-length filename).
#define LEVEL_0_MIN_HEADER_LEN 22 /* bytes */

// Minimum length of a level 1 base header (with zero-length filename).
#define LEVEL_1_MIN_HEADER_LEN 25 /* bytes */

// Length of a level 2 base header.
#define LEVEL_2_HEADER_LEN 26 /* bytes */

// Length of a level 3 base header.
#define LEVEL_3_HEADER_LEN 32 /* bytes */

// Maximum length of a level 3 header (including extended headers).
#define LEVEL_3_MAX_HEADER_LEN (1024 * 1024) /* 1 MB */

// Length of a level 0 Unix extended area.
#define LEVEL_0_UNIX_EXTENDED_LEN 12 /* bytes */

// Length of a level 0 OS-9 extended area.
#define LEVEL_0_OS9_EXTENDED_LEN 22 /* bytes */

#define RAW_DATA(hdr_ptr, off)  ((*hdr_ptr)->raw_data[off])
#define RAW_DATA_LEN(hdr_ptr)   ((*hdr_ptr)->raw_data_len)

char *lha_file_header_full_path(LHAFileHeader *header)
{
	char *path;
	char *filename;
	char *result;

	if (header->path != NULL) {
		path = header->path;
	} else {
		path = "";
	}

	if (header->filename != NULL) {
		filename = header->filename;
	} else {
		filename = "";
	}

	result = malloc(strlen(path) + strlen(filename) + 1);

	if (result == NULL) {
		return NULL;
	}

	sprintf(result, "%s%s", path, filename);

	return result;
}

/**
 * Given a file header with the filename set, split it into separate
 * path and filename components, if necessary.
 *
 * @param header         Point to the file header structure.
 * @return               Non-zero for success, or zero for failure.
 */

static int split_header_filename(LHAFileHeader *header)
{
	char *sep;
	char *new_filename;

	// Is there a directory separator in the path?  If so, we need to
	// split into directory name and filename.

	sep = strrchr(header->filename, '/');

	if (sep != NULL) {
		new_filename = strdup(sep + 1);

		if (new_filename == NULL) {
			return 0;
		}

		*(sep + 1) = '\0';
		header->path = header->filename;
		header->filename = new_filename;
	}

	return 1;
}

// Perform checksum of header contents.

static int check_l0_checksum(uint8_t *header, size_t header_len, size_t csum)
{
	unsigned int result;
	unsigned int i;

	result = 0;

	for (i = 0; i < header_len; ++i) {
		result += header[i];
	}

	return (result & 0xff) == csum;
}

// Perform full-header CRC check, based on CRC from "common" extended header.

static int check_common_crc(LHAFileHeader *header)
{
	uint16_t crc;

	crc = 0;
	lha_crc16_buf(&crc, header->raw_data, header->raw_data_len);

	return crc == header->common_crc;
}

// Decode MS-DOS timestamp.

static unsigned int decode_ftime(uint8_t *buf)
{
	int raw;
	struct tm datetime;

	raw = (int) lha_decode_uint32(buf);

	if (raw == 0) {
		return 0;
	}

	// Deconstruct the contents of the MS-DOS time value and populate the
	// 'datetime' structure. Note that 'mktime' generates a timestamp for
	// the local time zone: this is unfortunate, but probably the best
	// that can be done, due to the limited data stored in MS-DOS time
	// values.

	memset(&datetime, 0, sizeof(struct tm));

	datetime.tm_sec = (raw << 1) & 0x3e;
	datetime.tm_min = (raw >> 5) & 0x3f;
	datetime.tm_hour = (raw >> 11) & 0x1f;
	datetime.tm_mday = (raw >> 16) & 0x1f;
	datetime.tm_mon = ((raw >> 21) & 0xf) - 1;
	datetime.tm_year = 80 + ((raw >> 25) & 0x7f);
	datetime.tm_wday = 0;
	datetime.tm_yday = 0;
	datetime.tm_isdst = -1;

	return (unsigned int) mktime(&datetime);
}

// MS-DOS archives (and archives from similar systems) may have paths and
// filenames that are in all-caps. Detect these and convert them to
// lower-case.

static void fix_msdos_allcaps(LHAFileHeader *header)
{
	unsigned int i;
	int is_allcaps;

	// Check both path and filename to see if there are any lower-case
	// characters.

	is_allcaps = 1;

	if (header->path != NULL) {
		for (i = 0; header->path[i] != '\0'; ++i) {
			if (islower((int)(unsigned char) header->path[i])) {
				is_allcaps = 0;
				break;
			}
		}
	}

	if (is_allcaps && header->filename != NULL) {
		for (i = 0; header->filename[i] != '\0'; ++i) {
			if (islower((int)(unsigned char) header->filename[i])) {
				is_allcaps = 0;
				break;
			}
		}
	}

	// If both are all-caps, convert them all to lower-case.

	if (is_allcaps) {
		if (header->path != NULL) {
			for (i = 0; header->path[i] != '\0'; ++i) {
				header->path[i]
				    = tolower((int)(unsigned char) header->path[i]);
			}
		}
		if (header->filename != NULL) {
			for (i = 0; header->filename[i] != '\0'; ++i) {
				header->filename[i]
				    = tolower((int)(unsigned char) header->filename[i]);
			}
		}
	}
}

// Process the OS-9 permissions field and translate into the equivalent
// Unix permissions.

static void os9_to_unix_permissions(LHAFileHeader *header)
{
	unsigned int or, ow, oe, pr, pw, pe, d;

	// Translate into equivalent Unix permissions. OS-9 just has
	// owner and public, so double up public for the owner field.

	or = (header->os9_perms & 0x01) != 0;
	ow = (header->os9_perms & 0x02) != 0;
	oe = (header->os9_perms & 0x04) != 0;
	pr = (header->os9_perms & 0x08) != 0;
	pw = (header->os9_perms & 0x10) != 0;
	pe = (header->os9_perms & 0x20) != 0;
	d = (header->os9_perms & 0x80) != 0;

	header->extra_flags |= LHA_FILE_UNIX_PERMS;
	header->unix_perms = (d << 14)
	                   | (or << 8) | (ow << 7) | (oe << 6)  // owner
	                   | (pr << 5) | (pw << 4) | (pe << 3)  // group
	                   | (pr << 2) | (pw << 1) | (pe << 0); // everyone
}

// Parse a Unix symbolic link. These are stored in the format:
// filename = symlink|target

static int parse_symlink(LHAFileHeader *header)
{
	char *fullpath;
	char *p;

	// Although the format is always the same, some files have
	// symlink headers where the path is split between the path
	// and filename headers. For example:
	//    path = etc|../../
	//    filename = etc

	fullpath = lha_file_header_full_path(header);

	if (fullpath == NULL) {
		return 0;
	}

	p = strchr(fullpath, '|');

	if (p == NULL) {
		free(fullpath);
		return 0;
	}

	header->symlink_target = strdup(p + 1);

	if (header->symlink_target == NULL) {
		free(fullpath);
		return 0;
	}

	// Cut the string in half at the separator. Keep the left side
	// as the value for filename.

	*p = '\0';

	free(header->path);
	free(header->filename);
	header->path = NULL;
	header->filename = fullpath;

	// Having joined path and filename together during processing,
	// we now have the opposite problem: header->filename might
	// contain a full path rather than just a filename. Split back
	// into two again.

	return split_header_filename(header);
}

// Decode the path field in the header.

static int process_level0_path(LHAFileHeader *header, uint8_t *data,
                               size_t data_len)
{
	unsigned int i;

	// Zero-length filename probably means that this is a directory
	// entry. Leave the filename field as NULL - this makes us
	// consistent with level 2/3 headers.

	if (data_len == 0) {
		return 1;
	}

	header->filename = malloc(data_len + 1);

	if (header->filename == NULL) {
		return 0;
	}

	memcpy(header->filename, data, data_len);
	header->filename[data_len] = '\0';

	// Convert MS-DOS path separators to Unix path separators.

	for (i = 0; i < data_len; ++i) {
		if (header->filename[i] == '\\') {
			header->filename[i] = '/';
		}
	}

	return split_header_filename(header);
}

// Read some more data from the input stream, extending the raw_data
// array (and the size of the header).

static uint8_t *extend_raw_data(LHAFileHeader **header,
                                LHAInputStream *stream,
                                size_t nbytes)
{
	LHAFileHeader *new_header;
	size_t new_raw_len;
	uint8_t *result;

	if (nbytes > LEVEL_3_MAX_HEADER_LEN) {
		return NULL;
	}

	// Reallocate the header and raw_data area to be larger.

	new_raw_len = RAW_DATA_LEN(header) + nbytes;
	new_header = realloc(*header, sizeof(LHAFileHeader) + new_raw_len);

	if (new_header == NULL) {
		return NULL;
	}

	// Update the header pointer to point to the new area.

	*header = new_header;
	new_header->raw_data = (uint8_t *) (new_header + 1);
	result = new_header->raw_data + new_header->raw_data_len;

	// Read data from stream into new area.

	if (!lha_input_stream_read(stream, result, nbytes)) {
		return NULL;
	}

	new_header->raw_data_len = new_raw_len;

	return result;
}

// Starting at the specified offset in the raw_data array, walk
// through the list of extended headers and parse them.

static int decode_extended_headers(LHAFileHeader **header,
                                   unsigned int offset)
{
	unsigned int field_size;
	uint8_t *ext_header;
	size_t ext_header_len;
	size_t available_length;

	// Level 3 headers use 32-bit length fields; all others use
	// 16-bit fields.

	if ((*header)->header_level == 3) {
		field_size = 4;
	} else {
		field_size = 2;
	}

	available_length = RAW_DATA_LEN(header) - offset - field_size;

	while (offset <= RAW_DATA_LEN(header) - field_size) {
		ext_header = &RAW_DATA(header, offset + field_size);

		if (field_size == 4) {
			ext_header_len
			    = lha_decode_uint32(&RAW_DATA(header, offset));
		} else {
			ext_header_len
			    = lha_decode_uint16(&RAW_DATA(header, offset));
		}

		// Header length zero indicates end of chain. Otherwise, sanity
		// check the header length is valid.

		if (ext_header_len == 0) {
			break;
		} else if (ext_header_len < field_size + 1
		        || ext_header_len > available_length) {
			return 0;
		}

		// Process header:

		lha_ext_header_decode(*header, ext_header[0], ext_header + 1,
		                      ext_header_len - field_size - 1);

		// Advance to next header.

		offset += ext_header_len;
		available_length -= ext_header_len;
	}

	return 1;
}

static int read_next_ext_header(LHAFileHeader **header,
                                LHAInputStream *stream,
                                uint8_t **ext_header,
                                size_t *ext_header_len)
{
	// Last two bytes of the header raw data contain the size
	// of the next header.

	*ext_header_len
	    = lha_decode_uint16(&RAW_DATA(header, RAW_DATA_LEN(header) - 2));

	// No more headers?

	if (*ext_header_len == 0) {
		*ext_header = NULL;
		return 1;
	}

	*ext_header = extend_raw_data(header, stream, *ext_header_len);

	return *ext_header != NULL;
}

// Read extended headers for a level 1 header, extending the
// raw_data block to include them.

static int read_l1_extended_headers(LHAFileHeader **header,
                                    LHAInputStream *stream)
{
	uint8_t *ext_header;
	size_t ext_header_len;

	for (;;) {
		// Try to read the next header.

		if (!read_next_ext_header(header, stream,
		                          &ext_header, &ext_header_len)) {
			return 0;
		}

		// Last header?

		if (ext_header_len == 0) {
			break;
		}

		// For backwards compatibility with level 0 headers,
		// the compressed length field is actually "compressed
		// length + length of all extended headers":

		if ((*header)->compressed_length < ext_header_len) {
			return 0;
		}

		(*header)->compressed_length -= ext_header_len;

		// Must be at least 3 bytes - 1 byte header type
		// + 2 bytes for next header length

		if (ext_header_len < 3) {
			return 0;
		}
	}

	return 1;
}

// Process a level 0 Unix extended area.

static void process_level0_unix_area(LHAFileHeader *header,
                                     uint8_t *data, size_t data_len)
{
	// A typical Unix extended area:
	//
	// 00000000  55 00 00 3b 3d 4b 80 81  e8 03 e8 03

	// Sanity check.

	if (data_len < LEVEL_0_UNIX_EXTENDED_LEN || data[1] != 0x00) {
		return;
	}

	// OS-9/68k generates an extended area that is broadly compatible
	// with the Unix one.

	// Fill in the header fields from the data from the extended area.
	// There's one minor point to note here: OS-9/68k LHA includes the
	// timestamp twice - I have no idea why. In order to support both
	// variants, read the end fields from the end of the extended area.

	header->os_type = data[0];
	header->timestamp = lha_decode_uint32(data + 2);

	header->unix_perms = lha_decode_uint16(data + data_len - 6);
	header->unix_uid = lha_decode_uint16(data + data_len - 4);
	header->unix_gid = lha_decode_uint16(data + data_len - 2);

	header->extra_flags |= LHA_FILE_UNIX_PERMS | LHA_FILE_UNIX_UID_GID;
}

// Process a level 0 OS-9 extended area.

static void process_level0_os9_area(LHAFileHeader *header,
                                    uint8_t *data, size_t data_len)
{
	// A typical OS-9 extended area:
	//
	// 00000000  39 13 00 00 c3 16 00 0f  00 cc 18 07 09 03 01 16
	// 00000010  00 13 00 00 00 00

	// Sanity checks:

	if (data_len < LEVEL_0_OS9_EXTENDED_LEN
	 || data[9] != 0xcc || data[1] != data[17] || data[2] != data[18]) {
		return;
	}

	// The contents resemble the contents of the OS-9 extended header.
	// We just want the permissions field.

	header->os_type = LHA_OS_TYPE_OS9;
	header->os9_perms = lha_decode_uint16(data + 1);
	header->extra_flags |= LHA_FILE_OS9_PERMS;
}

// Handling for level 0 extended areas.

static void process_level0_extended_area(LHAFileHeader *header,
                                         uint8_t *data, size_t data_len)
{
	// PMarc archives can include comments that are stored in the
	// extended area. It is possible that this could conflict with
	// the logic below, so specifically exclude them.

	if (!strncmp(header->compress_method, "-pm", 3)) {
		return;
	}

	// Different tools include different extended areas. Try to
	// identify which tool generated this one, based on the first
	// byte.

	switch (data[0]) {
		case LHA_OS_TYPE_UNIX:
		case LHA_OS_TYPE_OS9_68K:
			process_level0_unix_area(header, data, data_len);
			break;

		case LHA_OS_TYPE_OS9:
			process_level0_os9_area(header, data, data_len);
			break;

		default:
			break;
	}
}

// Decode a level 0 or 1 header.

static int decode_level0_header(LHAFileHeader **header, LHAInputStream *stream)
{
	uint8_t header_len;
	uint8_t header_csum;
	size_t path_len;
	size_t min_len;

	header_len = RAW_DATA(header, 0);
	header_csum = RAW_DATA(header, 1);

	// Sanity check header length.  This is the minimum header length
	// for a header that has a zero-length path.

	switch ((*header)->header_level) {
		case 0:
			min_len = LEVEL_0_MIN_HEADER_LEN;
			break;
		case 1:
			min_len = LEVEL_1_MIN_HEADER_LEN;
			break;

		default:
			return 0;
	}

	if (header_len < min_len) {
		return 0;
	}

	// We only have a partial header so far. Read the full header.

	if (!extend_raw_data(header, stream,
	                     header_len + 2 - RAW_DATA_LEN(header))) {
		return 0;
	}

	// Checksum the header.

	if (!check_l0_checksum(&RAW_DATA(header, 2),
	                       RAW_DATA_LEN(header) - 2,
	                       header_csum)) {
		return 0;
	}

	// Compression method:

	memcpy((*header)->compress_method, &RAW_DATA(header, 2), 5);
	(*header)->compress_method[5] = '\0';

	// File lengths:

	(*header)->compressed_length = lha_decode_uint32(&RAW_DATA(header, 7));
	(*header)->length = lha_decode_uint32(&RAW_DATA(header, 11));

	// Timestamp:

	(*header)->timestamp = decode_ftime(&RAW_DATA(header, 15));

	// Read path.  Check path length field - is the header long enough
	// to hold this full path?

	path_len = RAW_DATA(header, 21);

	if (min_len + path_len > header_len) {
		return 0;
	}

	// OS type?

	if ((*header)->header_level == 0) {
		(*header)->os_type = LHA_OS_TYPE_UNKNOWN;
	} else {
		(*header)->os_type = RAW_DATA(header, 24 + path_len);
	}

	// Read filename field:

	if (!process_level0_path(*header, &RAW_DATA(header, 22), path_len)) {
		return 0;
	}

	// CRC field.

	(*header)->crc = lha_decode_uint16(&RAW_DATA(header, 22 + path_len));

	// Level 0 headers can contain extended data through different schemes
	// to the extended header system used in level 1+.

	if ((*header)->header_level == 0
	 && header_len > LEVEL_0_MIN_HEADER_LEN + path_len) {
		process_level0_extended_area(*header,
		  &RAW_DATA(header, LEVEL_0_MIN_HEADER_LEN + 2 + path_len),
		  header_len - LEVEL_0_MIN_HEADER_LEN - path_len);
	}

	return 1;
}

static int decode_level1_header(LHAFileHeader **header, LHAInputStream *stream)
{
	unsigned int ext_header_start;

	if (!decode_level0_header(header, stream)) {
		return 0;
	}

	// Level 1 headers can have extended headers, so parse them.

	ext_header_start = RAW_DATA_LEN(header) - 2;

	if (!read_l1_extended_headers(header, stream)
	 || !decode_extended_headers(header, ext_header_start)) {
		return 0;
	}

	return 1;
}

static int decode_level2_header(LHAFileHeader **header, LHAInputStream *stream)
{
	unsigned int header_len;

	header_len = lha_decode_uint16(&RAW_DATA(header, 0));

	if (header_len < LEVEL_2_HEADER_LEN) {
		return 0;
	}

	// Read the full header.

	if (!extend_raw_data(header, stream,
	                     header_len - RAW_DATA_LEN(header))) {
		return 0;
	}

	// Compression method:

	memcpy((*header)->compress_method, &RAW_DATA(header, 2), 5);
	(*header)->compress_method[5] = '\0';

	// File lengths:

	(*header)->compressed_length = lha_decode_uint32(&RAW_DATA(header, 7));
	(*header)->length = lha_decode_uint32(&RAW_DATA(header, 11));

	// Timestamp. Unlike level 0/1, this is a Unix-style timestamp.

	(*header)->timestamp = lha_decode_uint32(&RAW_DATA(header, 15));

	// CRC.

	(*header)->crc = lha_decode_uint16(&RAW_DATA(header, 21));

	// OS type:

	(*header)->os_type = RAW_DATA(header, 23);

	// LHA for OS-9/68k generates broken level 2 archives: the header
	// length field is the length of the remainder of the header, not
	// the complete header length. As a result it's two bytes too
	// short. We can use the OS type field to detect these archives
	// and compensate.

	if ((*header)->os_type == LHA_OS_TYPE_OS9_68K) {
		if (!extend_raw_data(header, stream, 2)) {
			return 0;
		}
	}

	if (!decode_extended_headers(header, 24)) {
		return 0;
	}

	return 1;
}

static int decode_level3_header(LHAFileHeader **header, LHAInputStream *stream)
{
	unsigned int header_len;

	// The first field at the start of a level 3 header is supposed to
	// indicate word size, with the idea being that the header format
	// can be extended beyond 32-bit words in the future. In practise,
	// nothing supports anything other than 32-bit (4 bytes), and neither
	// do we.

	if (lha_decode_uint16(&RAW_DATA(header, 0)) != 4) {
		return 0;
	}

	// Read the full header.

	if (!extend_raw_data(header, stream,
	                     LEVEL_3_HEADER_LEN - RAW_DATA_LEN(header))) {
		return 0;
	}

	// Read the header length field (including extended headers), and
	// extend to this full length. Because this is a 32-bit value,
	// we must place a sensible limit on the amount of data that will
	// be read, to avoid possibly allocating gigabytes of memory.

	header_len = lha_decode_uint32(&RAW_DATA(header, 24));

	if (header_len > LEVEL_3_MAX_HEADER_LEN
	 || header_len < RAW_DATA_LEN(header)) {
		return 0;
	}

	if (!extend_raw_data(header, stream,
	                     header_len - RAW_DATA_LEN(header))) {
		return 0;
	}

	// Compression method:

	memcpy((*header)->compress_method, &RAW_DATA(header, 2), 5);
	(*header)->compress_method[5] = '\0';

	// File lengths:

	(*header)->compressed_length = lha_decode_uint32(&RAW_DATA(header, 7));
	(*header)->length = lha_decode_uint32(&RAW_DATA(header, 11));

	// Unix-style timestamp.

	(*header)->timestamp = lha_decode_uint32(&RAW_DATA(header, 15));

	// CRC.

	(*header)->crc = lha_decode_uint16(&RAW_DATA(header, 21));

	// OS type:

	(*header)->os_type = RAW_DATA(header, 23);

	if (!decode_extended_headers(header, 28)) {
		return 0;
	}

	return 1;
}


// "Collapse" a path down, by removing all instances of "." and ".."
// paths. This is to protect against malicious archives that might include
// ".." in a path to break out of the extract directory.

static void collapse_path(char *filename)
{
	unsigned int currpath_len;
	char *currpath;
	char *r, *w;

	// If the path starts with a /, it is an absolute path; skip over
	// that first character and don't remove it.

	if (filename[0] == '/') {
		++filename;
	}

	// Step through each character, copying it from 'r' to 'w'. It
	// is always the case that w <= r, and the final string will
	// be equal in length or shorter than the original.

	currpath = filename;
	w = filename;

	for (r = filename; *r != '\0'; ++r) {
		*w++ = *r;

		// Each time a new path separator is found, examine the
		// path that was just written.

		if (*r == '/') {

			currpath_len = w - currpath - 1;

			// Empty path (//) or current directory (.)?

			if (currpath_len == 0
			 || (currpath_len == 1 && currpath[0] == '.')) {
				w = currpath;

			// Parent directory (..)?

			} else if (currpath_len == 2
			        && currpath[0] == '.' && currpath[1] == '.') {

				// Walk back up by one directory. Don't go
				// past the start of the string.

				if (currpath == filename) {
					w = filename;
				} else {
					w = currpath - 1;

					while (w > filename) {
						if (*(w - 1) == '/') {
							break;
						}
						--w;
					}

					currpath = w;
				}

			// Save for next time we start a new path.

			} else {
				currpath = w;
			}
		}
	}

	*w = '\0';
}

LHAFileHeader *lha_file_header_read(LHAInputStream *stream)
{
	LHAFileHeader *header;
	int success;

	// We cannot decode the file header until we identify the
	// header level (as different header level formats are
	// decoded in different ways. The header level field is
	// located at byte offset 20 within the header, so we
	// must read the first 21 bytes to read it (actually this
	// reads one byte more, so that we get the filename length
	// byte for level 1 headers as well).

	// Allocate result structure.

	header = calloc(1, sizeof(LHAFileHeader) + COMMON_HEADER_LEN);

	if (header == NULL) {
		return NULL;
	}

	memset(header, 0, sizeof(LHAFileHeader));

	header->_refcount = 1;

	// Read first chunk of header.

	header->raw_data = (uint8_t *) (header + 1);
	header->raw_data_len = COMMON_HEADER_LEN;

	if (!lha_input_stream_read(stream, header->raw_data,
	                           header->raw_data_len)) {
		goto fail;
	}

	// Identify header level, and decode header depending on
	// the value encountered.

	header->header_level = header->raw_data[20];

	switch (header->header_level) {
		case 0:
			success = decode_level0_header(&header, stream);
			break;

		case 1:
			success = decode_level1_header(&header, stream);
			break;

		case 2:
			success = decode_level2_header(&header, stream);
			break;

		case 3:
			success = decode_level3_header(&header, stream);
			break;

		default:
			success = 0;
			break;
	}

	if (!success) {
		goto fail;
	}

	// Some Amiga archives have directory entries mistakenly encoded
	// as -lh0- rather than -lhd-. These look like regular files
	// without a filename, which is obviously incorrect. So we catch
	// this case and fix the compress_method field.

	if (header->os_type == LHA_OS_TYPE_AMIGA
	 && strcmp(header->compress_method, "-lh0-") == 0
	 && header->length == 0 && header->filename == NULL) {
		memcpy(header->compress_method, LHA_COMPRESS_TYPE_DIR, 5);
	}

	// Sanity check that we got some headers, at least.
	// Directory entries must have a path, and files must have a
	// filename. Symlinks are stored using the same compression method
	// field string (-lhd-) as directories.

	if (strcmp(header->compress_method, LHA_COMPRESS_TYPE_DIR) != 0) {
		if (header->filename == NULL) {
			goto fail;
		}
	} else if (!strcmp(header->compress_method, LHA_COMPRESS_TYPE_DIR)
	        && LHA_FILE_HAVE_EXTRA(header, LHA_FILE_UNIX_PERMS)
		&& (header->path != NULL || header->filename != NULL)
		&& (header->unix_perms & 0170000) == 0120000) {

		if (!parse_symlink(header)) {
			goto fail;
		}

	} else {
		if (header->path == NULL) {
			goto fail;
		}
	}

	// Is the path an all-caps filename?  If so, it is a DOS path that
	// should be translated to lower case.

	if (header->os_type == LHA_OS_TYPE_UNKNOWN
	 || header->os_type == LHA_OS_TYPE_MSDOS
	 || header->os_type == LHA_OS_TYPE_ATARI
	 || header->os_type == LHA_OS_TYPE_LHARK
	 || header->os_type == LHA_OS_TYPE_OS2) {
		fix_msdos_allcaps(header);
	}

	// Collapse special directory paths to ensure the path is clean.

	if (header->path != NULL) {
		collapse_path(header->path);
	}

	// Is this header generated by OS-9/68k LHA? If so, any Unix
	// permissions are actually OS-9 permissions.

	if (header->os_type == LHA_OS_TYPE_OS9_68K
	 && LHA_FILE_HAVE_EXTRA(header, LHA_FILE_UNIX_PERMS)) {
		header->os9_perms = header->unix_perms;
		header->extra_flags |= LHA_FILE_OS9_PERMS;
	}

	// If OS-9 permissions were read, translate into Unix permissions.

	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_OS9_PERMS)) {
		os9_to_unix_permissions(header);
	}

	// Was the "common" extended header read, which contains a CRC of
	// the full header? If so, perform a CRC check now.

	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_COMMON_CRC)
	 && !check_common_crc(header)) {
		goto fail;
	}

	// The DOS LHARK tool has its own -lh7- format that is incompatible
	// with the -lh7- that everyone else uses. As a workaround, we detect
	// and rename the compression method to -lk7- so as to be able to
	// distinguish between the two formats.
	if (header->header_level == 1 && header->os_type == LHA_OS_TYPE_LHARK
	 && !strncmp(header->compress_method, "-lh7-", 5)) {
		header->compress_method[2] = 'k';
	}

	return header;
fail:
	lha_file_header_free(header);
	return NULL;
}

void lha_file_header_free(LHAFileHeader *header)
{
	// Sanity check:

	if (header->_refcount == 0) {
		return;
	}

	// Count down references and only free when all have been removed.

	--header->_refcount;

	if (header->_refcount > 0) {
		return;
	}

	free(header->filename);
	free(header->path);
	free(header->symlink_target);
	free(header->unix_username);
	free(header->unix_group);
	free(header);
}

void lha_file_header_add_ref(LHAFileHeader *header)
{
	++header->_refcount;
}
