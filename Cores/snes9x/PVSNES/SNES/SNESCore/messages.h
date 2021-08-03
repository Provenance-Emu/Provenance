/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _MESSAGES_H_
#define _MESSAGES_H_

// Types of message sent to S9xMessage()
enum
{
	S9X_TRACE,
	S9X_DEBUG,
	S9X_WARNING,
	S9X_INFO,
	S9X_ERROR,
	S9X_FATAL_ERROR
};

// Individual message numbers
enum
{
	S9X_NO_INFO,
	S9X_ROM_INFO,
	S9X_HEADERS_INFO,
	S9X_CONFIG_INFO,
	S9X_ROM_CONFUSING_FORMAT_INFO,
	S9X_ROM_INTERLEAVED_INFO,
	S9X_SOUND_DEVICE_OPEN_FAILED,
	S9X_APU_STOPPED,
	S9X_USAGE,
	S9X_GAME_GENIE_CODE_ERROR,
	S9X_ACTION_REPLY_CODE_ERROR,
	S9X_GOLD_FINGER_CODE_ERROR,
	S9X_DEBUG_OUTPUT,
	S9X_DMA_TRACE,
	S9X_HDMA_TRACE,
	S9X_WRONG_FORMAT,
	S9X_WRONG_VERSION,
	S9X_ROM_NOT_FOUND,
	S9X_FREEZE_FILE_NOT_FOUND,
	S9X_PPU_TRACE,
	S9X_TRACE_DSP1,
	S9X_FREEZE_ROM_NAME,
	S9X_HEADER_WARNING,
	S9X_NETPLAY_NOT_SERVER,
	S9X_FREEZE_FILE_INFO,
	S9X_TURBO_MODE,
	S9X_SOUND_NOT_BUILT,
	S9X_MOVIE_INFO,
	S9X_WRONG_MOVIE_SNAPSHOT,
	S9X_NOT_A_MOVIE_SNAPSHOT,
	S9X_SNAPSHOT_INCONSISTENT,
	S9X_AVI_INFO,
	S9X_PRESSED_KEYS_INFO
};

#endif
