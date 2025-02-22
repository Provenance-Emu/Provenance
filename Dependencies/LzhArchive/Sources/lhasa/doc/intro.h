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

/* This file is a dummy header used to generate the Doxygen intro. */

/**
 * @mainpage Lhasa LZH file library
 *
 * @section Introduction
 *
 * Lhasa is a library for parsing LHA (.lzh) archive files. Included
 * with the library is a Unix command line tool that is an interface
 * compatible replacement for the non-free Unix LHA tool.
 *
 * The source code is licensed under the ISC license, a simplified
 * version of the MIT/X11 license which is functionally identical,
 * and compatible with the GNU GPL.
 * As such, it may be reused in any project, either proprietary or
 * open source.
 *
 * @section Main_interfaces Main interfaces
 *
 * @li @link lha_input_stream.h @endlink - abstracts
 *     the process of reading data from an LZH file; convenience
 *     functions are provided for reading data from a normal file or
 *     a Standard C FILE pointer.
 * @li @link lha_reader.h @endlink - routines to decode ands
 *     extract the contents of an LZH file from a stream.
 * @li @link lha_file_header.h @endlink - structure
 *     representing the decoded contents of an LZH file header.
 *
 * @section Additional_interfaces Additional interfaces
 *
 * @li @link lha_decoder.h @endlink - routines to decode raw LZH
 *     compressed data.
 */
