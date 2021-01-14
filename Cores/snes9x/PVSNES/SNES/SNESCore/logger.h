/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _LOGGER_H_
#define _LOGGER_H_

void S9xResetLogger(void);
void S9xCloseLogger(void);
void S9xVideoLogger(void *, int, int, int, int);
void S9xAudioLogger(void *, int);

#endif
