//
//  PVPlayCore+Audio.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Audio.h"

@implementation PVPlayCore (Audio)

- (NSTimeInterval)frameInterval {
    return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return sampleRate;
}

@end

#pragma mark - Sound callbacks

//void CSH_OpenEmu::Reset()
//{
//
//}
//
//bool CSH_OpenEmu::HasFreeBuffers()
//{
//	return true;
//}
//
//void CSH_OpenEmu::RecycleBuffers()
//{
//
//}
//
//void CSH_OpenEmu::Write(int16 *audio, unsigned int sampleCount, unsigned int sampleRate)
//{
//	GET_CURRENT_OR_RETURN();
//
//	OERingBuffer *rb = [current audioBufferAtIndex:0];
//	[rb write:audio maxLength:sampleCount*2];
//}
//
//static CSoundHandler *SoundHandlerFactory()
//{
//	OESetThreadRealtime(1. / (1 * 60), .007, .03);
//	return new CSH_OpenEmu();
//}
//
//CSoundHandler::FactoryFunction CSH_OpenEmu::GetFactoryFunction()
//{
//	return SoundHandlerFactory;
//}
