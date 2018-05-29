//
//  BWUnanchoredButtonContainer.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

// See the integration class

#import "BWUnanchoredButtonContainer.h"

@implementation BWUnanchoredButtonContainer

- (void)awakeFromNib
{
	for (NSView *subview in [self subviews])
	{
		[subview setFrameSize:NSMakeSize(subview.frame.size.width, 22)];
	}
}

@end
