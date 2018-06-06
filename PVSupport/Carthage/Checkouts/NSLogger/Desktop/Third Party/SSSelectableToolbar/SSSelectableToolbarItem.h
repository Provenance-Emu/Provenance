//
//  SSToolbarItem.h
//  SelectableToolbarHelper
//
//  Created by Steven Streeting on 19/06/2011.
//  Copyright 2011 Torus Knot Software Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SSSelectableToolbarItem : NSToolbarItem 
{
	NSView* linkedView;
}

@property (nonatomic, retain) IBOutlet NSView* linkedView;

@end
