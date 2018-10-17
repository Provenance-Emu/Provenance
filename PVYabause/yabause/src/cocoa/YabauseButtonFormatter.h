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

#ifndef YabauseButtonFormatter_h
#define YabauseButtonFormatter_h

#import <Cocoa/Cocoa.h>


@interface YabauseButtonFormatter : NSFormatter {
}

- (NSString *)stringForObjectValue:(id)obj;
- (BOOL)getObjectValue:(id *)obj
             forString:(NSString *)str 
      errorDescription:(NSString **)err;

-       (BOOL)control:(NSControl*)control
             textView:(NSTextView*)textView
  doCommandBySelector:(SEL)commandSelector;

@end /* @interface YabauseButtonFormatter */

#endif /* !YabauseButtonFormatter_h */
