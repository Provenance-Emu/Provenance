/*
    Simple Core Audio backend for osx (and maybe ios?)
    Based off various audio core samples and dolphin's code
 
    This is part of the Reicast project, please consult the
    LICENSE file for licensing & related information
 
    This could do with some locking logic to avoid
    race conditions, and some variable length buffer
    logic to support chunk sizes other than 512 bytes
 
    It does work on my macmini though
 */

#include "oslib/audiobackend_coreaudio.h"


#if HOST_OS == OS_DARWIN
#import "OEGameAudio.h"

static OEGameAudio __strong* gameAudio;

// We're making these functions static - there's no need to pollute the global namespace
static void coreaudio_init()
{
	gameAudio = [[OEGameAudio alloc] init];
	[gameAudio startAudio];
}

static u32 coreaudio_push(void* frame, u32 samples, bool wait)
{
//	while (samples_ptr != 0 && wait)
//		;
//
//	if (samples_ptr == 0) {
		[[gameAudio ringBufferAtIndex:0] write:(const unsigned char *)frame maxLength:samples * 4];
//	});
    /* Yeah, right */
//    while (samples_ptr != 0 && wait) ;
//
//    if (samples_ptr == 0) {
//        memcpy(&samples_temp[samples_ptr], frame, samples * 4);
//        samples_ptr += samples * 4;
//    }
//
    return 1;
}

static void coreaudio_term()
{
	[gameAudio stopAudio];
	gameAudio = nil;
}

audiobackend_t audiobackend_coreaudio = {
    "coreaudio", // Slug
    "Core Audio", // Name
    &coreaudio_init,
    &coreaudio_push,
    &coreaudio_term
};
#endif
