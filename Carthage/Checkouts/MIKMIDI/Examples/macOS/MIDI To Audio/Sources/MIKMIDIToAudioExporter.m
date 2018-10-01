//
//  MIKStudioMIDIToAudioExporter.m
//  StudioTime
//
//  Created by Andrew Madsen on 2/13/15.
//  Copyright (c) 2015-2016 Mixed In Key LLC. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#import "MIKMIDIToAudioExporter.h"
#import <MIKMIDI/MIKMIDI.h>
#import "MIKOfflineMIDISynthesizer.h"

@interface MIKMIDIToAudioExporter ()

@property (nonatomic, strong) MIKMIDISequencer *sequencer;
@property (nonatomic, strong) MIKOfflineMIDISynthesizer *synthesizer;

@property (nonatomic, copy) MIKStudioMIDIToAudioExporterCompletionBlock completionBlock;

@end

@implementation MIKMIDIToAudioExporter

+ (instancetype)exporterWithMIDIFileAtURL:(NSURL *)fileURL
{
	return [[self alloc] initWithMIDIFileAtURL:fileURL];
}

- (instancetype)initWithMIDIFileAtURL:(NSURL *)fileURL;
{
	self = [super init];
	if (self) {
		_midiFileURL = fileURL;
	}
	return self;
}

- (instancetype)init
{
	[NSException raise:NSInternalInconsistencyException format:@"Use -initWithMIDIFileAtURL:"];
	self = [self init];
	return nil;
}

- (void)exportToAudioFileWithCompletionHandler:(MIKStudioMIDIToAudioExporterCompletionBlock)completionBlock
{
	self.completionBlock = ^(NSURL *url, NSError *error){ if (completionBlock) completionBlock(url, error); };
	
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:self.midiFileURL error:&error];
	if (!sequence) return [self finishWithError:error];
	
	self.synthesizer = [[MIKOfflineMIDISynthesizer alloc] init];
	self.synthesizer.tracks = sequence.tracks;
	self.synthesizer.tempo = [sequence tempoAtTimeStamp:0];
	
	[self.synthesizer export];
	
	[self finishWithError:nil];
}

- (void)finishWithError:(NSError *)error
{
	if (error) NSLog(@"MIKStudioMIDIToAudioExporter encountered an error: %@", error);
	self.completionBlock(self.synthesizer.outputFileURL, error);
}

@end
