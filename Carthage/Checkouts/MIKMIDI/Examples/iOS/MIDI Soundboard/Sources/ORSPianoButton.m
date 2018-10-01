//
//  ORSPianoButton.m
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/4/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import "ORSPianoButton.h"
#import <QuartzCore/QuartzCore.h>
#import <MIKMIDI/MIKMIDI.h>

@implementation ORSPianoButton

- (void)drawRect:(CGRect)rect
{
	[[UIColor darkGrayColor] set];
	[[UIBezierPath bezierPathWithRect:[self bounds]] stroke];
}

#pragma mark - MIKMIDIResponder

- (NSString *)MIDIIdentifier { return [NSString stringWithFormat:@"PianoKey%li", (long)[self tag]]; }

- (BOOL)respondsToMIDICommand:(MIKMIDICommand *)command
{
	if (command.commandType != MIKMIDICommandTypeNoteOn) return NO;
	
	MIKMIDINoteOnCommand *noteCommand = (MIKMIDINoteOnCommand *)command;
	return (noteCommand.note - 60) == self.tag;
}

- (void)handleMIDICommand:(MIKMIDICommand *)command
{
	if (command.commandType != MIKMIDICommandTypeNoteOn) return;
	
	MIKMIDINoteOnCommand *noteCommand = (MIKMIDINoteOnCommand *)command;
	if (noteCommand.velocity == 0) return;
	
	[self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

@end
