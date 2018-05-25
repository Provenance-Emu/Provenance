//
//  SSToolbar.m
//  SelectableToolbarHelper
//
//  Created by Steven Streeting on 19/06/2011.
//  Copyright 2011 Torus Knot Software Ltd. All rights reserved.
//

#import "SSSelectableToolbar.h"
#import "SSSelectableToolbarItem.h"


@implementation SSSelectableToolbar
@synthesize window;
@synthesize defaultItemIndex;

- (id) initWithIdentifier:(NSString *)identifier
{
	if (self = [super initWithIdentifier:identifier])
	{
		blankView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
	}
	return self;
}

- (void) dealloc
{
	[blankView release];
	[window release];
	[super dealloc];

}
-(IBAction)toolbarItemClicked:sender
{
	// this is really only here so I can set up a target / action which makes button clickable
}

-(void)selectDefaultItem:sender
{
	// select the default item first time becomes key
	[self selectItemWithIndex:defaultItemIndex];
	// Don't tell us again
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];

}

-(void) awakeFromNib
{
	// Set target / action on all buttons to make them clickable
	NSArray* items = [self visibleItems];
	for (NSToolbarItem* item in items)
	{
		if ([item isKindOfClass:[SSSelectableToolbarItem class]])
		{
			[item setTarget:self];
			[item setAction:@selector(toolbarItemClicked:)];			
		}
	}
	
	// Wait until window displayed before sizing (important for displaying in sheets)
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(selectDefaultItem:)
												 name:NSWindowDidBecomeKeyNotification 
											   object:window];
	

}

-(NSToolbarItem*)itemWithIdentifier:(NSString*)identifier
{
	for (NSToolbarItem* item in [self items])
	{
		if ([[item itemIdentifier] isEqual:identifier])
			return item;
	}
	return nil;
}

- (void)setSelectedItemIdentifier:(NSString *)itemIdentifier
{
	[super setSelectedItemIdentifier:itemIdentifier];
	
	NSToolbarItem* item = [self itemWithIdentifier:itemIdentifier];
	if ([item isKindOfClass:[SSSelectableToolbarItem class]])
	{
		SSSelectableToolbarItem* ssitem = (SSSelectableToolbarItem*)item;
		
		NSView* view = [ssitem linkedView];
		if (view && window)
		{
			NSView* oldView = [window contentView];
			NSRect oldFrame = [oldView frame];
			NSRect newFrame = [view frame];
			NSRect oldWinFrame = [window frame];
			NSRect winFrame = oldWinFrame;
			float toolbarHeight = NSHeight(oldWinFrame) - NSHeight(oldFrame);

			// resize
			winFrame.size.width = newFrame.size.width;
			winFrame.size.height = newFrame.size.height + toolbarHeight;
			winFrame.origin.y -=  NSHeight(winFrame) - NSHeight(oldWinFrame);
			[window setContentView:blankView];
			[window setFrame:winFrame display:YES animate:YES];
			[window setContentView:view];
			
			// change title
			[window setTitle:[ssitem label]];
			
			// tab to first control (if nextKeyView connected)
			NSView* keyView = [view nextKeyView];
			if (keyView)
				[window makeFirstResponder:keyView];
			
			
		}
	}
}

-(void)selectItemWithIndex:(NSInteger)idx
{
	NSInteger currIdx = 0;
	for (NSToolbarItem* item in [self items])
	{
		if ([item isKindOfClass:[SSSelectableToolbarItem class]])
		{
			if (currIdx == idx)
			{
				[self setSelectedItemIdentifier:[item itemIdentifier]];
				return;
			}
			// We're only counting these types, ignore spacing and other default items
			++currIdx;
		}
	}
			
}

-(NSInteger)selectableItemIndexToMainIndex:(NSInteger)idx
{
	NSInteger selIdx = 0;
	NSInteger mainIdx = 0;
	for (NSToolbarItem* item in [self items])
	{
		if ([item isKindOfClass:[SSSelectableToolbarItem class]])
		{
			if (selIdx == idx)
			{
				return mainIdx;
			}
			++selIdx;
		}
		++mainIdx;
	}
	
	return -1;
}
@end
