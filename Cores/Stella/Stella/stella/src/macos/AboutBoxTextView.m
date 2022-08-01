//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#import "AboutBoxTextView.h"
#import "AboutBox.h"

@implementation AboutBoxTextView
/*------------------------------------------------------------------------------
*  mouseDown - This method notifies the AboutBox class of a mouse click, then
*    calls the normal text view mouseDown.
*-----------------------------------------------------------------------------*/
- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent clickCount] >= 2)
    [[AboutBox sharedInstance] doubleClicked];
  else
    [[AboutBox sharedInstance] clicked];
  [super mouseDown:theEvent];
}

@end
