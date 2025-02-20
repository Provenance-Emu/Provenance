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

#ifndef LHASA_PUBLIC_LHA_READER_H
#define LHASA_PUBLIC_LHA_READER_H

#include "lha_decoder.h"
#include "lha_input_stream.h"
#include "lha_file_header.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @file lha_reader.h
 *
 * @brief LHA file reader.
 *
 * This file contains the interface functions for the @ref LHAReader
 * structure, used to decode data from a compressed LZH file and
 * extract compressed files.
 */

/**
 * Opaque structure used to decode the contents of an LZH file.
 */

typedef struct _LHAReader LHAReader;

/**
 * Policy for extracting directories.
 *
 * When extracting a directory, some of the metadata associated with
 * it needs to be set after the contents of the directory have been
 * extracted. This includes the modification time (which would
 * otherwise be reset to the current time) and the permissions (which
 * can affect the ability to extract files into the directory).
 * To work around this problem there are several ways of handling
 * directory extraction.
 */

typedef enum {

	/**
	 * "Plain" policy. In this mode, the metadata is set at the
	 * same time that the directory is created. This is the
	 * simplest to comprehend, and the files returned from
	 * @ref lha_reader_next_file will match the files in the
	 * archive, but it is not recommended.
	 */

	LHA_READER_DIR_PLAIN,

	/**
	 * "End of directory" policy. In this mode, if a directory
	 * is extracted, the directory name will be saved. Once the
	 * contents of the directory appear to have been extracted
	 * (i.e. a file is found that is not within the directory),
	 * the directory will be returned again by
	 * @ref lha_reader_next_file. This time, when the directory
	 * is "extracted" (via @ref lha_reader_extract), the metadata
	 * will be set.
	 *
	 * This method uses less memory than
	 * @ref LHA_READER_DIR_END_OF_FILE, but there is the risk
	 * that a file will appear within the archive after the
	 * metadata has been set for the directory. However, this is
	 * not normally the case, as files and directories typically
	 * appear within an archive in order. GNU tar uses the same
	 * method to address this problem with tar files.
	 *
	 * This is the default policy.
	 */

	LHA_READER_DIR_END_OF_DIR,

	/**
	 * "End of file" policy. In this mode, each directory that
	 * is extracted is recorded in a list. When the end of the
	 * archive is reached, these directories are returned again by
	 * @ref lha_reader_next_file. When the directories are
	 * "extracted" again (via @ref lha_reader_extract), the
	 * metadata is set.
	 *
	 * This avoids the problems that can potentially occur with
	 * @ref LHA_READER_DIR_END_OF_DIR, but uses more memory.
	 */

	LHA_READER_DIR_END_OF_FILE

} LHAReaderDirPolicy;

/**
 * Create a new @ref LHAReader to read data from an @ref LHAInputStream.
 *
 * @param stream     The input stream to read data from.
 * @return           Pointer to a new @ref LHAReader structure,
 *                   or NULL for error.
 */

LHAReader *lha_reader_new(LHAInputStream *stream);

/**
 * Free a @ref LHAReader structure.
 *
 * @param reader     The @ref LHAReader structure.
 */

void lha_reader_free(LHAReader *reader);

/**
 * Set the @ref LHAReaderDirPolicy used to extract directories.
 *
 * @param reader     The @ref LHAReader structure.
 * @param policy     The policy to use for directories.
 */

void lha_reader_set_dir_policy(LHAReader *reader,
                               LHAReaderDirPolicy policy);

/**
 * Read the header of the next archived file from the input stream.
 *
 * @param reader     The @ref LHAReader structure.
 * @return           Pointer to an @ref LHAFileHeader structure, or NULL if
 *                   an error occurred.  This pointer is only valid until
 *                   the next time that lha_reader_next_file is called.
 */

LHAFileHeader *lha_reader_next_file(LHAReader *reader);

/**
 * Read some of the (decompresed) data for the current archived file,
 * decompressing as appropriate.
 *
 * @param reader     The @ref LHAReader structure.
 * @param buf        Pointer to a buffer in which to store the data.
 * @param buf_len    Size of the buffer, in bytes.
 * @return           Number of bytes stored in the buffer, or zero if
 *                   there is no more data to decompress.
 */

size_t lha_reader_read(LHAReader *reader, void *buf, size_t buf_len);

/**
 * Decompress the contents of the current archived file, and check
 * that the checksum matches correctly.
 *
 * @param reader         The @ref LHAReader structure.
 * @param callback       Callback function to invoke to monitor progress (or
 *                       NULL if progress does not need to be monitored).
 * @param callback_data  Extra data to pass to the callback function.
 * @return               Non-zero if the checksum matches.
 */

int lha_reader_check(LHAReader *reader,
                     LHADecoderProgressCallback callback,
                     void *callback_data);

/**
 * Extract the contents of the current archived file.
 *
 * @param reader         The @ref LHAReader structure.
 * @param filename       Filename to extract the archived file to, or NULL
 *                       to use the path and filename from the header.
 * @param callback       Callback function to invoke to monitor progress (or
 *                       NULL if progress does not need to be monitored).
 * @param callback_data  Extra data to pass to the callback function.
 * @return               Non-zero for success, or zero for failure (including
 *                       CRC error).
 */

int lha_reader_extract(LHAReader *reader,
                       char *filename,
                       LHADecoderProgressCallback callback,
                       void *callback_data);

/**
 * Check if the current file (last returned by @ref lha_reader_next_file)
 * was generated internally by the extract process. This occurs when a
 * directory or symbolic link must be created as a two-stage process, with
 * some of the extraction process deferred to later in the stream.
 *
 * These "fake" duplicates should usually be hidden in the user interface
 * when a summary of extraction is presented.
 *
 * @param reader         The @ref LHAReader structure.
 * @return               Non-zero if the current file is a "fake", or zero
 *                       for a normal file.
 */

int lha_reader_current_is_fake(LHAReader *reader);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef LHASA_PUBLIC_LHA_READER_H */
