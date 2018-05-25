/*
 * LoggerTableView.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2017 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 * 
 */
#import "LoggerTableView.h"
#import "LoggerMessageCell.h"

@implementation LoggerTableView

@synthesize timestampColumnWidth, threadIDColumnWidth;

- (void) dealloc
{
	[tableTrackingArea release];
	[timestampSeparatorTrackingArea release];
	[threadSeparatorTrackingArea release];
	[super dealloc];
}

#pragma mark -
#pragma mark MouseOver support

- (void)updateTrackingAreas
{
	// @@@ TODO
}

#pragma mark -
#pragma mark Dragging support

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
	// Don't understand why I have to override this method, but it's the only
	// way I could get dragging from table to work. Tried various additional
	// things with no luck...
    
    if([self columnAtPoint:mouseDownPoint] > -1 && [self rowAtPoint:mouseDownPoint] > -1)
    {
        NSCell *clickedCell = [self preparedCellAtColumn:[self columnAtPoint:mouseDownPoint] row:[self rowAtPoint:mouseDownPoint]];
        if([clickedCell respondsToSelector:@selector(isColumnResizingHotPoint:inView:)]) // LoggerMessageCell 
            return ( ! [(LoggerMessageCell*)clickedCell isColumnResizingHotPoint:mouseDownPoint inView:self] );
    }
    
	return YES;
}

@end
