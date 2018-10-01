//
//  MIKMIDITrackView.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/23/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDISequenceView.h"
#import <MIKMIDI/MIKMIDI.h>

void * MIKMIDISequenceViewKVOContext = &MIKMIDISequenceViewKVOContext;

@interface MIKMIDISequenceView ()

@property (nonatomic) BOOL dragInProgress;

@property (nonatomic, strong, readonly) NSArray *noteColors;

@end

@implementation MIKMIDISequenceView

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self registerForDraggedTypes:@[NSFilenamesPboardType]];
	}
	return self;
}

- (void)dealloc
{
	self.sequence = nil;
}

#pragma mark - Layout

- (NSSize)intrinsicContentSize
{
	double maxLength = [[self.sequence valueForKeyPath:@"tracks.@max.length"] doubleValue];
	return NSMakeSize(maxLength * [self pixelsPerTick], 250.0);
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect
{
	if (self.dragInProgress) {
		[[NSColor lightGrayColor] set];
		NSRectFill([self bounds]);
	}
	
	CGFloat ppt = [self pixelsPerTick];
	CGFloat noteHeight = [self pixelsPerNote];
	NSInteger index=0;
	NSArray *tracks = self.sequence.tracks;
	for (MIKMIDITrack *track in tracks) {
		
		for (MIKMIDINoteEvent *note in [track notes]) {
			CGFloat yPosition = NSMinY([self bounds]) + note.note * [self pixelsPerNote];
			NSRect noteRect = NSMakeRect(NSMinX([self bounds]) + note.timeStamp * ppt, yPosition, note.duration * ppt, noteHeight);

			[[NSColor blackColor] set];
			NSRectFill(noteRect);
			NSColor *noteColor = [tracks count] < 2 ? [self colorForNote:note] : [self colorForTrackAtIndex:index];
			[noteColor set];
			NSRectFill(NSInsetRect(noteRect, 1.0, 1.0));
		}
		index++;
	}
}

#pragma mark - NSDraggingDestination

- (NSArray *)MIDIFilesFromPasteboard:(NSPasteboard *)pb
{
	if (![[pb types] containsObject:NSFilenamesPboardType]) return NSDragOperationNone;
	
	NSArray *files = [pb propertyListForType:NSFilenamesPboardType];
	files = [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *file, NSDictionary *bindings) {
		return [[file pathExtension] isEqualToString:@"mid"] || [[file pathExtension] isEqualToString:@"midi"];
	}]];
	return files;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	NSArray *files = [self MIDIFilesFromPasteboard:[sender draggingPasteboard]];
	self.dragInProgress = [files count] != 0;
	return [files count] ? NSDragOperationCopy : NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	self.dragInProgress = NO;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	NSArray *files = [self MIDIFilesFromPasteboard:[sender draggingPasteboard]];
	if (![files count]) return NO;
	
	if ([self.delegate respondsToSelector:@selector(midiSequenceView:receivedDroppedMIDIFiles:)]) {
		[self.delegate midiSequenceView:self receivedDroppedMIDIFiles:files];
	}
	
	return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
	self.dragInProgress = NO;
}

#pragma mark - Private

- (NSColor *)colorForNote:(MIKMIDINoteEvent *)note
{
	NSInteger notePosition = (note.note % 12);
	return self.noteColors[notePosition];
}

- (NSColor *)colorForTrackAtIndex:(NSInteger)index
{
	NSInteger indexIntoColors = index % 12;
	return self.noteColors[indexIntoColors];
}

- (CGFloat)pixelsPerTick
{
	return 15.0;
}

- (CGFloat)pixelsPerNote
{
	return NSHeight([self bounds]) / 127.0;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != MIKMIDISequenceViewKVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	if ([keyPath isEqualToString:@"length"]) {
		[self invalidateIntrinsicContentSize];
	}
	
	if ([keyPath isEqualToString:@"tracks"]) {
		[self unregisterForKVOOnTracks:change[NSKeyValueChangeOldKey]];
		[self registerForKVOOnTracks:change[NSKeyValueChangeNewKey]];
		
		[self setNeedsDisplay:YES];
	}
	
	if ([object isKindOfClass:[MIKMIDITrack class]]) {
		[self invalidateIntrinsicContentSize];
		[self setNeedsDisplay:YES];
	}
}

- (void)registerForKVOOnTracks:(NSArray *)tracks
{
	for (MIKMIDITrack *track in tracks) {
		[track addObserver:self forKeyPath:@"events" options:0 context:MIKMIDISequenceViewKVOContext];
	}
}

- (void)unregisterForKVOOnTracks:(NSArray *)tracks
{
	for (MIKMIDITrack *track in tracks) {
		[track removeObserver:self forKeyPath:@"events"];
	}
}

#pragma mark - Properties

- (void)setSequence:(MIKMIDISequence *)sequence
{
	if (sequence != _sequence) {
		
		[_sequence removeObserver:self forKeyPath:@"length"];
		[_sequence removeObserver:self forKeyPath:@"tracks"];
		[self unregisterForKVOOnTracks:_sequence.tracks];
		
		_sequence = sequence;
		
		[_sequence addObserver:self forKeyPath:@"length" options:NSKeyValueObservingOptionInitial context:MIKMIDISequenceViewKVOContext];
		NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		[_sequence addObserver:self forKeyPath:@"tracks" options:options context:MIKMIDISequenceViewKVOContext];
		if (_sequence) [self registerForKVOOnTracks:_sequence.tracks];
	}
}

- (void)setDragInProgress:(BOOL)dragInProgress
{
	if (dragInProgress != _dragInProgress) {
		_dragInProgress = dragInProgress;
		[self setNeedsDisplay:YES];
	}
}

@synthesize noteColors = _noteColors;
- (NSArray *)noteColors
{
	if (!_noteColors) {
		_noteColors = @[[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:1.0 green:0.227 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:1.0 green:0.454 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:1.0 green:0.681 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:1.0 green:0.909 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.727 green:1.0 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.272 green:1.0 blue:0.0 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.0 green:0.818 blue:0.181 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.0 green:0.363 blue:0.636 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.045 green:0.0 blue:0.954 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.272 green:0.0 blue:0.727 alpha:1.0],
						[NSColor colorWithCalibratedRed:0.5 green:0.0 blue:0.5 alpha:1.0]];
	}
	return _noteColors;
}

@end
