/*  Copyright 2011 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "YabauseButtonFormatter.h"
#include <objc/runtime.h>

@implementation YabauseButtonFormatter

- (NSString *)stringForObjectValue:(id)obj
{
    if(![obj isKindOfClass:[NSString class]]) {
        return nil;
    }

    if([obj length] >= 1) {
        return [obj substringToIndex:1];
    }
    else {
        return [NSString string];
    }
}

- (BOOL)getObjectValue:(id *)obj
             forString:(NSString *)str
      errorDescription:(NSString **)err
{
    if(obj) {
        if([str length] >= 1) {
            *obj = [NSString stringWithString:[str substringToIndex:1]];
        }
        else {
            *obj = [NSString string];
        }
    }

    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString 
       originalSelectedRange:(NSRange)origSelRange 
            errorDescription:(NSString **)error
{
    NSString *rs = [[*partialStringPtr substringToIndex:1] uppercaseString];

    *partialStringPtr = rs;
    *proposedSelRangePtr = NSMakeRange(0, [rs length]);

    return NO;
}

-       (BOOL)control:(NSControl*)control
             textView:(NSTextView*)textView
  doCommandBySelector:(SEL)commandSelector
{
    BOOL result = NO;

    /* handle all the fun special cases... */
    if(commandSelector == @selector(insertNewline:)) {
        [textView insertText:@"\u23CE"]; 
        result = YES;
    }
    else if(commandSelector == @selector(insertTab:)) {
        [textView insertText:@"\u21E5"];
        result = YES;
    }
    else if(commandSelector == @selector(cancelOperation:)) {
        [textView insertText:@"\u241B"];
        result = YES;
    }
    else if(commandSelector == @selector(deleteBackward:)) {
        [textView insertText:@"\u232B"];
        result = YES;
    }
    else if(commandSelector == @selector(moveLeft:)) {
        [textView insertText:@"\u2190"];
        result = YES;
    }
    else if(commandSelector == @selector(moveUp:)) {
        [textView insertText:@"\u2191"];
        result = YES;
    }
    else if(commandSelector == @selector(moveRight:)) {
        [textView insertText:@"\u2192"];
        result = YES;
    }
    else if(commandSelector == @selector(moveDown:)) {
        [textView insertText:@"\u2193"];
        result = YES;
    }

    return result;
}

@end /* @implementation YabauseButtonFormatter */
