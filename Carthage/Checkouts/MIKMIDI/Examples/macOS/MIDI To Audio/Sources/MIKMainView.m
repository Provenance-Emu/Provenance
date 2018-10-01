//
//  MIKMainView.m
//  MIDI To Audio
//
//  Created by Andrew Madsen on 2/13/15.
//  Copyright (c) 2015-2016 Mixed In Key. All rights reserved.
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

#import "MIKMainView.h"

@interface MIKMainView ()

@property (nonatomic) BOOL dragIsActive;

@end

@implementation MIKMainView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
	if (self.dragIsActive) {
		[[NSColor grayColor] setFill];
		[[NSColor darkGrayColor] setStroke];
		[[NSBezierPath bezierPathWithRect:[self bounds]] fill];
		[[NSBezierPath bezierPathWithRect:[self bounds]] stroke];
	} else {
		[[NSColor whiteColor] set];
		NSRectFill([self bounds]);
	}
}

#pragma mark - Drag/Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	NSURL *fileURL = [self fileURLFromDraggingInfo:sender];
	if (!fileURL) return NSDragOperationNone;
	if (![self.delegate shouldAllowDropForFile:fileURL]) return NSDragOperationNone;

	self.dragIsActive = YES;
	return NSDragOperationCopy;
}

- (void)draggingEnded:(id<NSDraggingInfo>)sender
{
	self.dragIsActive = NO;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	self.dragIsActive = NO;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	NSURL *fileURL = [self fileURLFromDraggingInfo:sender];
	if (!fileURL) return NO;

	[self.delegate fileWasDropped:fileURL];
	
	return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
	self.dragIsActive = NO;
}

- (NSURL *)fileURLFromDraggingInfo:(id<NSDraggingInfo>)info
{
	NSPasteboard *pb = [info draggingPasteboard];
	NSArray *paths = [pb propertyListForType:NSFilenamesPboardType];
	NSURL *fileURL = nil;
	for (NSString *path in paths) {
		fileURL = [NSURL fileURLWithPath:path];
		if (fileURL) return fileURL;
	}
	return nil;
}

#pragma mark - Properties

- (void)setDragIsActive:(BOOL)dragIsActive
{
	if (dragIsActive != _dragIsActive) {
		_dragIsActive = dragIsActive;
		[self setNeedsDisplay:YES];
	}
}

@end
