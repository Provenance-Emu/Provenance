/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _LANGUAGE_H_
#define _LANGUAGE_H_

// Movie Messages
#define MOVIE_ERR_SNAPSHOT_WRONG_MOVIE	"Snapshot not from this movie"
#define MOVIE_ERR_SNAPSHOT_NOT_MOVIE	"Not a movie snapshot"
#define MOVIE_INFO_REPLAY				"Movie replay"
#define MOVIE_INFO_RECORD				"Movie record"
#define MOVIE_INFO_RERECORD				"Movie re-record"
#define MOVIE_INFO_REWIND				"Movie rewind"
#define MOVIE_INFO_STOP					"Movie stop"
#define MOVIE_INFO_END					"Movie end"
#define MOVIE_INFO_SNAPSHOT				"Movie snapshot"
#define MOVIE_ERR_SNAPSHOT_INCONSISTENT	"Snapshot inconsistent with movie"

// Snapshot Messages
#define SAVE_INFO_SNAPSHOT				"Saved"
#define SAVE_INFO_LOAD					"Loaded"
#define SAVE_INFO_OOPS					"Auto-saving 'oops' snapshot"
#define SAVE_ERR_WRONG_FORMAT			"File not in Snes9x snapshot format"
#define SAVE_ERR_WRONG_VERSION			"Incompatible snapshot version"
#define SAVE_ERR_ROM_NOT_FOUND			"ROM image \"%s\" for snapshot not found"
#define SAVE_ERR_SAVE_NOT_FOUND			"Snapshot %s does not exist"

#endif
