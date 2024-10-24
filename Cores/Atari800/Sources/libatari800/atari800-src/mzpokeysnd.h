#ifndef MZPOKEYSND_H_
#define MZPOKEYSND_H_

#include "atari.h"

int MZPOKEYSND_Init(ULONG freq17,
                        int playback_freq,
                        UBYTE num_pokeys,
                        int flags,
                        int quality
#ifdef __PLUS
                        , int clear_regs
#endif
                       );

#endif /* MZPOKEYSND_H_ */
