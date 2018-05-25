//
//  SSToolbar.h
//  SelectableToolbarHelper
//
//  Created by Steven Streeting on 19/06/2011.
//  Copyright 2011 Torus Knot Software Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SSSelectableToolbar : NSToolbar 
{
	NSWindow* window;
	NSView* blankView;
	NSInteger defaultItemIndex;
}
@property (nonatomic, retain) IBOutlet NSWindow* window;
@property (nonatomic, assign) NSInteger defaultItemIndex;

-(NSToolbarItem*)itemWithIdentifier:(NSString*)identifier;
// select the item with the given index, ordered as per the palette and ignoring 
// all types of buttons except SSSelectableToolbarItem
-(void)selectItemWithIndex:(NSInteger)idx;
// Convert a selectable item index (ignoring all except selectable items in palette)
// to a main index which can be used for other purposes
-(NSInteger)selectableItemIndexToMainIndex:(NSInteger)idx;
@end
