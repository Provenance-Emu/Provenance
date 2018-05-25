//
//  SSToolbarItem.m
//  SelectableToolbarHelper
//
//  Created by Steven Streeting on 19/06/2011.
//  Copyright 2011 Torus Knot Software Ltd. All rights reserved.
//

#import "SSSelectableToolbarItem.h"


@implementation SSSelectableToolbarItem

@synthesize linkedView;

-(void) dealloc
{
	[linkedView release];
	[super dealloc];
}

@end
