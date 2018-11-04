/*
 * LoggerWindowController.m
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
#import <sys/time.h>
#import "LoggerWindowController.h"
#import "LoggerDetailsWindowController.h"
#import "LoggerMessageCell.h"
#import "LoggerClientInfoCell.h"
#import "LoggerMarkerCell.h"
#import "LoggerMessage.h"
#import "LoggerAppDelegate.h"
#import "LoggerCommon.h"
#import "LoggerDocument.h"
#import "LoggerSplitView.h"
#import "LoggerUtils.h"

#define kMaxTableRowHeight @"maxTableRowHeight"

@interface LoggerWindowController ()
@property (nonatomic, retain) NSString *info;
@property (nonatomic, retain) NSString *filterString;
@property (nonatomic, retain) NSMutableSet *filterTags;
- (void)rebuildQuickFilterPopup;
- (void)updateClientInfo;
- (void)updateFilterPredicate;
- (void)refreshAllMessages:(NSArray *)selectMessages;
- (void)filterIncomingMessages:(NSArray *)messages withFilter:(NSPredicate *)aFilter tableFrameSize:(NSSize)tableFrameSize;
- (NSPredicate *)filterPredicateFromCurrentSelection;
- (void)tileLogTable:(BOOL)forceUpdate;
- (void)rebuildMarksSubmenu;
- (void)clearMarksSubmenu;
- (void)rebuildRunsSubmenu;
- (void)clearRunsSubmenu;
@end

static NSString * const kNSLoggerFilterPasteboardType = @"com.florentpillet.NSLoggerFilter";
static NSArray *sXcodeFileExtensions = nil;

@implementation LoggerWindowController

@synthesize info, filterString, filterTags;
@synthesize attachedConnection;
@synthesize messagesSelected, hasQuickFilter;
@synthesize threadColumnWidth;
@dynamic showFunctionNames;

// -----------------------------------------------------------------------------
#pragma mark -
#pragma Standard NSWindowController stuff
// -----------------------------------------------------------------------------
- (id)initWithWindowNibName:(NSString *)nibName
{
	if ((self = [super initWithWindowNibName:nibName]) != nil)
	{
		messageFilteringQueue = dispatch_queue_create("com.florentpillet.nslogger.messageFiltering", NULL);
		displayedMessages = [[NSMutableArray alloc] initWithCapacity:4096];
		tags = [[NSMutableSet alloc] init];
		filterTags = [[NSMutableSet alloc] init];
		[self setShouldCloseDocument:YES];
        threadColumnWidth = DEFAULT_THREAD_COLUMN_WIDTH;
	}
	return self;
}

- (void)dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:kMaxTableRowHeight];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[detailsWindowController release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[filterSetsListController removeObserver:self forKeyPath:@"arrangedObjects"];
	[filterSetsListController removeObserver:self forKeyPath:@"selectedObjects"];
	[filterListController removeObserver:self forKeyPath:@"selectedObjects"];
	dispatch_release(messageFilteringQueue);
	[attachedConnection release];
	[info release];
	[filterString release];
	[filterTags release];
	[filterPredicate release];
	[displayedMessages release];
	[tags release];
	[messageCell release];
	[clientInfoCell release];
	[markerCell release];
	if (lastTilingGroup)
		dispatch_release(lastTilingGroup);

    logTable.delegate = nil;
    logTable.dataSource = nil;
	filterSetsTable.delegate = nil;
    filterSetsTable.dataSource = nil;
	filterTable.delegate = nil;
    filterTable.dataSource = nil;
    
    [super dealloc];
}

- (NSUndoManager *)undoManager
{
	return [[self document] undoManager];
}

- (void)windowDidLoad
{
    if (sXcodeFileExtensions == nil) {
        sXcodeFileExtensions = [[NSArray alloc] initWithObjects:
                                @"m", @"mm", @"h", @"c", @"cp", @"cpp", @"hpp", @"swift",
                                nil];
    }
    
	if ([[self window] respondsToSelector:@selector(setRestorable:)])
		[[self window] setRestorable:NO];

	messageCell = [[LoggerMessageCell alloc] init];
	clientInfoCell = [[LoggerClientInfoCell alloc] init];
	markerCell = [[LoggerMarkerCell alloc] init];

	[logTable setIntercellSpacing:NSMakeSize(0,0)];
	[logTable setTarget:self];
	[logTable setDoubleAction:@selector(logCellDoubleClicked:)];

	[logTable registerForDraggedTypes:[NSArray arrayWithObject:NSPasteboardTypeString]];
	[logTable setDraggingSourceOperationMask:NSDragOperationNone forLocal:YES];
	[logTable setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

	[filterSetsTable registerForDraggedTypes:[NSArray arrayWithObject:kNSLoggerFilterPasteboardType]];
	[filterSetsTable setIntercellSpacing:NSMakeSize(0,0)];

	[filterTable registerForDraggedTypes:[NSArray arrayWithObject:kNSLoggerFilterPasteboardType]];
	[filterTable setVerticalMotionCanBeginDrag:YES];
	[filterTable setTarget:self];
	[filterTable setIntercellSpacing:NSMakeSize(0,0)];
	[filterTable setDoubleAction:@selector(startEditingFilter:)];

	[filterSetsListController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:NULL];
	[filterSetsListController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	[filterListController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];

	buttonBar.splitViewDelegate = self;
    splitView.delegate = self;

	[self rebuildQuickFilterPopup];
	[self updateFilterPredicate];
		
	[logTable sizeToFit];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applyFontChanges)
												 name:kMessageAttributesChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tileLogTableNotification:)
												 name:@"TileLogTableNotification"
											   object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kMaxTableRowHeight options:0 context:NULL];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	if ([[self document] fileURL] != nil)
		return displayName;
	if (attachedConnection.connected)
		return [attachedConnection clientAppDescription];
	return [NSString stringWithFormat:NSLocalizedString(@"%@ (disconnected)", @""),
			[attachedConnection clientDescription]];
}

- (void)updateClientInfo
{
	// Update the source label
	assert([NSThread isMainThread]);
	[self synchronizeWindowTitleWithDocumentName];
}

- (void)updateMenuBar:(BOOL)documentIsFront
{
	if (documentIsFront)
	{
		[self rebuildMarksSubmenu];
		[self rebuildRunsSubmenu];
	}
	else
	{
		[self clearRunsSubmenu];
		[self clearMarksSubmenu];
	}
}

- (void)tileLogTableMessages:(NSArray *)messages
					withSize:(NSSize)tableSize
				 forceUpdate:(BOOL)forceUpdate
					   group:(dispatch_group_t)group
{
	// check for cancellation
	if (group != NULL && dispatch_get_context(group) == NULL)
		return;

	NSMutableArray *updatedMessages = [[NSMutableArray alloc] initWithCapacity:[messages count]];
    NSSize maxCellSize = tableSize;
    NSInteger maxRowHeight = [[NSUserDefaults standardUserDefaults] integerForKey:kMaxTableRowHeight];
    if (maxRowHeight >= 30 && maxCellSize.height > maxRowHeight)
        maxCellSize.height = maxRowHeight;
    
	for (LoggerMessage *msg in messages)
	{
		// detect cancellation
		if (group != NULL && dispatch_get_context(group) == NULL)
			break;

		// compute size
		NSSize cachedSize = msg.cachedCellSize;
		if (forceUpdate || cachedSize.width != tableSize.width)
		{
			CGFloat cachedHeight = cachedSize.height;
			CGFloat newHeight = cachedHeight;
			if (forceUpdate)
				msg.cachedCellSize = NSZeroSize;
			switch (msg.type)
			{
				case LOGMSG_TYPE_LOG:
				case LOGMSG_TYPE_BLOCKSTART:
				case LOGMSG_TYPE_BLOCKEND:
					newHeight = [LoggerMessageCell heightForCellWithMessage:msg threadColumnWidth:threadColumnWidth maxSize:maxCellSize showFunctionNames:showFunctionNames];
					break;
				case LOGMSG_TYPE_CLIENTINFO:
				case LOGMSG_TYPE_DISCONNECT:
					newHeight = [LoggerClientInfoCell heightForCellWithMessage:msg threadColumnWidth:threadColumnWidth maxSize:maxCellSize showFunctionNames:showFunctionNames];
					break;
				case LOGMSG_TYPE_MARK:
					newHeight = [LoggerMarkerCell heightForCellWithMessage:msg threadColumnWidth:threadColumnWidth maxSize:maxCellSize showFunctionNames:showFunctionNames];
					break;
			}
			if (newHeight != cachedHeight)
				[updatedMessages addObject:msg];
			else if (forceUpdate)
				msg.cachedCellSize = cachedSize;
		}
	}
	if ([updatedMessages count])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (group == NULL || dispatch_get_context(group) != NULL)
			{
				NSMutableIndexSet *set = [[NSMutableIndexSet alloc] init];
				for (LoggerMessage *msg in updatedMessages)
				{
					NSUInteger pos = [displayedMessages indexOfObjectIdenticalTo:msg];
					if (pos == NSNotFound || pos > lastMessageRow)
						break;
					[set addIndex:pos];
				}
				if ([set count])
					[logTable noteHeightOfRowsWithIndexesChanged:set];
				[set release];
			}
		});
	}
	[updatedMessages release];
}

- (void)cancelAsynchronousTiling
{
	if (lastTilingGroup != NULL)
	{
		dispatch_group_t leaveGroup = lastTilingGroup;
		dispatch_set_context(leaveGroup, NULL);
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			// by clearing the context, all further tasks on this group will cancel their work
			// wait until they all went through cancellation before removing the group
			dispatch_group_wait(leaveGroup, 0);
			dispatch_release(leaveGroup);
		});
	}
	lastTilingGroup = NULL;
}

- (void)tileLogTable:(BOOL)forceUpdate
{
	// tile the visible rows (and a bit more) first, then tile all the rest
	// this gives us a better perceived speed
	NSSize tableSize = [logTable frame].size;
	NSRect r = [[logTable superview] convertRect:[[logTable superview] bounds] toView:logTable];
	NSRange visibleRows = [logTable rowsInRect:r];
	visibleRows.location = MAX((int)0, (int)visibleRows.location - 10);
	visibleRows.length = MIN(visibleRows.location + visibleRows.length + 10, [displayedMessages count] - visibleRows.location);
	if (visibleRows.length)
	{
		[self tileLogTableMessages:[displayedMessages subarrayWithRange:visibleRows]
						  withSize:tableSize
					   forceUpdate:forceUpdate
							 group:NULL];
	}
	
	[self cancelAsynchronousTiling];
	
	// create new group, set it a non-NULL context to indicate that it is running
	lastTilingGroup = dispatch_group_create();
	dispatch_set_context(lastTilingGroup, "running");
	
	// perform layout in chunks in the background
	for (NSUInteger i = 0; i < [displayedMessages count]; i += 1024)
	{
		// tiling is executed on a parallel queue, and checks for cancellation
		// by looking at its group's context object 
		NSRange range = NSMakeRange(i, MIN(1024, [displayedMessages count] - i));
		if (range.length > 0)
		{
			NSArray *subArray = [displayedMessages subarrayWithRange:range];
			dispatch_group_t group = lastTilingGroup;		// careful with self dereference, could use the wrong group at run time, hence the copy here
			dispatch_group_async(group,
								 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
								 ^{
									 [self tileLogTableMessages:subArray
													   withSize:tableSize
													forceUpdate:forceUpdate
														  group:group];
								 });
		}
	}
}

- (void)tileLogTableNotification:(NSNotification *)note
{
	[self tileLogTable:NO];
}

- (void)applyFontChanges
{
	[self tileLogTable:YES];
	[logTable reloadData];
}

#pragma mark Target Action

- (IBAction)performFindPanelAction:(id)sender {
    [self.window makeFirstResponder:quickFilterTextField];
}


// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Support for multiple runs in same window
// -----------------------------------------------------------------------------
- (void)rebuildRunsSubmenu
{
	LoggerDocument *doc = (LoggerDocument *)self.document;
	NSMenuItem *runsSubmenu = [[[[NSApp mainMenu] itemWithTag:VIEW_MENU_ITEM_TAG] submenu] itemWithTag:VIEW_MENU_SWITCH_TO_RUN_TAG];
	NSArray *runsNames = [doc attachedLogsPopupNames];
	NSMenu *menu = [runsSubmenu submenu];
	[menu removeAllItems];
	NSInteger i = 0;
	NSInteger currentRun = [[doc indexOfCurrentVisibleLog] integerValue];
	for (NSString *name in runsNames)
	{
		NSMenuItem *runItem = [[NSMenuItem alloc] initWithTitle:name
														 action:@selector(selectRun:)
												  keyEquivalent:@""];
		if (i == currentRun)
			[runItem setState:NSOnState];
		[runItem setTag:i++];
		[runItem setTarget:self];
		[menu addItem:runItem];
		[runItem release];
	}
}

- (void)clearRunsSubmenu
{
	NSMenuItem *runsSubmenu = [[[[NSApp mainMenu] itemWithTag:VIEW_MENU_ITEM_TAG] submenu] itemWithTag:VIEW_MENU_SWITCH_TO_RUN_TAG];
	NSMenu *menu = [runsSubmenu submenu];
	[menu removeAllItems];
	NSMenuItem *dummyItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Run Log", @"") action:nil keyEquivalent:@""];
	[dummyItem setEnabled:NO];
	[menu addItem:dummyItem];
	[dummyItem release];
}

- (void)selectRun:(NSMenuItem *)anItem
{
	((LoggerDocument *)self.document).indexOfCurrentVisibleLog = [NSNumber numberWithInteger:[anItem tag]];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Filter predicate assembly
// -----------------------------------------------------------------------------
- (NSPredicate *)filterPredicateFromCurrentSelection
{
	// the current filter is the aggregate (OR clause) of all the selected filters
	NSArray *predicates = [[filterListController selectedObjects] valueForKey:@"predicate"];
	if (![predicates count])
		return nil;
	if ([predicates count] == 1)
		return [predicates lastObject];
	
	// Isolate the NOT type predicates, merge predicates this way:
	// result = (AND all NOT predicates)) AND (OR all ANY/ALL predicates)
	NSMutableArray *anyAllPredicates = [NSMutableArray arrayWithCapacity:[predicates count]];
	NSMutableArray *notPredicates = [NSMutableArray arrayWithCapacity:[predicates count]];
	for (NSCompoundPredicate *pred in predicates)
	{
		if ([pred isKindOfClass:[NSCompoundPredicate class]] && [pred compoundPredicateType] == NSNotPredicateType)
			[notPredicates addObject:pred];
		else
			[anyAllPredicates addObject:pred];
	}
	if ([notPredicates count] && [anyAllPredicates count])
	{
		return [NSCompoundPredicate andPredicateWithSubpredicates:
				[NSArray arrayWithObjects:
				 [NSCompoundPredicate andPredicateWithSubpredicates:notPredicates],
				 [NSCompoundPredicate orPredicateWithSubpredicates:anyAllPredicates],
				 nil]];
	}
	if ([notPredicates count])
		return [NSCompoundPredicate andPredicateWithSubpredicates:notPredicates];
	return [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
}

- (NSPredicate *)alwaysVisibleEntriesPredicate
{
	NSExpression *lhs = [NSExpression expressionForKeyPath:@"type"];
	NSExpression *rhs = [NSExpression expressionForConstantValue:[NSSet setWithObjects:
																  [NSNumber numberWithInteger:LOGMSG_TYPE_MARK],
																  [NSNumber numberWithInteger:LOGMSG_TYPE_CLIENTINFO],
																  [NSNumber numberWithInteger:LOGMSG_TYPE_DISCONNECT],
																  nil]];
	return [NSComparisonPredicate predicateWithLeftExpression:lhs
											  rightExpression:rhs
													 modifier:NSDirectPredicateModifier
														 type:NSInPredicateOperatorType
													  options:0];
}

- (void)updateFilterPredicate
{
	assert([NSThread isMainThread]);
	NSPredicate *p = [self filterPredicateFromCurrentSelection];
	NSMutableArray *andPredicates = [[NSMutableArray alloc] initWithCapacity:3];
	if (logLevel)
	{
		NSExpression *lhs = [NSExpression expressionForKeyPath:@"level"];
		NSExpression *rhs = [NSExpression expressionForConstantValue:[NSNumber numberWithInteger:logLevel]];
		[andPredicates addObject:[NSComparisonPredicate predicateWithLeftExpression:lhs
																	rightExpression:rhs
																		   modifier:NSDirectPredicateModifier
																			   type:NSLessThanPredicateOperatorType
																			options:0]];
	}
	if (filterTags.count != 0)
	{
		NSMutableArray *filterTagsPredicates = [[NSMutableArray alloc] initWithCapacity:filterTags.count];
		for (NSString *filterTag in filterTags) {
			NSExpression *lhs = [NSExpression expressionForKeyPath:@"tag"];
			NSExpression *rhs = [NSExpression expressionForConstantValue:filterTag];
			[filterTagsPredicates addObject:[NSComparisonPredicate predicateWithLeftExpression:lhs
																			   rightExpression:rhs
																					  modifier:NSDirectPredicateModifier
																						  type:NSEqualToPredicateOperatorType
																					   options:0]];
		}
		[andPredicates addObject:[NSCompoundPredicate orPredicateWithSubpredicates:filterTagsPredicates]];
		[filterTagsPredicates release];
	}
	if ([filterString length])
	{
		// "refine filter" string looks up in both message text and function name
		NSExpression *lhs = [NSExpression expressionForKeyPath:@"messageText"];
		NSExpression *rhs = [NSExpression expressionForConstantValue:filterString];
		NSPredicate *messagePredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs
																		   rightExpression:rhs
																				  modifier:NSDirectPredicateModifier
																					  type:NSContainsPredicateOperatorType
																				   options:NSCaseInsensitivePredicateOption];
		lhs = [NSExpression expressionForKeyPath:@"functionName"];
		NSPredicate *functionPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs
																			rightExpression:rhs
																				   modifier:NSDirectPredicateModifier
																					   type:NSContainsPredicateOperatorType
																					options:NSCaseInsensitivePredicateOption];
		
		[andPredicates addObject:[NSCompoundPredicate orPredicateWithSubpredicates:
								  [NSArray arrayWithObjects:messagePredicate, functionPredicate, nil]]];
	}
	if ([andPredicates count])
	{
		if (p != nil)
			[andPredicates addObject:p];
		p = [NSCompoundPredicate andPredicateWithSubpredicates:andPredicates];
	}
	if (p == nil)
		p = [NSPredicate predicateWithValue:YES];
	else
		p = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:[self alwaysVisibleEntriesPredicate], p, nil]];
	[filterPredicate autorelease];
	filterPredicate = [p retain];
	[andPredicates release];
}

- (void)refreshMessagesIfPredicateChanged
{
	assert([NSThread isMainThread]);
	NSPredicate *currentPredicate = [[filterPredicate retain] autorelease];
	[self updateFilterPredicate];
	if (![filterPredicate isEqual:currentPredicate])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshAllMessages:) object:nil];
		[self rebuildQuickFilterPopup];
		[self performSelector:@selector(refreshAllMessages:) withObject:nil afterDelay:0];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Per-Application settings
// -----------------------------------------------------------------------------
- (NSDictionary *)settingsForClientApplication
{
	NSString *clientAppIdentifier = [attachedConnection clientName];
	if (![clientAppIdentifier length])
		return nil;

	NSDictionary *clientSettings = [[NSUserDefaults standardUserDefaults] objectForKey:kPrefClientApplicationSettings];
	if (clientSettings == nil)
		return [NSDictionary dictionary];
	
	NSDictionary *appSettings = [clientSettings objectForKey:clientAppIdentifier];
	if (appSettings == nil)
		return [NSDictionary dictionary];
	return appSettings;
}

- (void)saveSettingsForClientApplication:(NSDictionary *)newSettings
{
	NSString *clientAppIdentifier = [attachedConnection clientName];
	if (![clientAppIdentifier length])
		return;
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *clientSettings = [[[ud objectForKey:kPrefClientApplicationSettings] mutableCopy] autorelease];
	if (clientSettings == nil)
		clientSettings = [NSMutableDictionary dictionary];
	[clientSettings setObject:newSettings forKey:clientAppIdentifier];
	[ud setObject:clientSettings forKey:kPrefClientApplicationSettings];
}

- (void)setSettingForClientApplication:(id)aValue forKey:(NSString *)aKey
{
	NSMutableDictionary *dict = [[self settingsForClientApplication] mutableCopy];
	[dict setObject:aValue forKey:aKey];
	[self saveSettingsForClientApplication:dict];
	[dict release];
}

- (void)rememberFiltersSelection
{
	// remember the last filter set selected for this application identifier,
	// we will use it to automatically reassociate it the next time the same
	// application connects or a log file from this application is reopened
	NSDictionary *filterSet = [[filterSetsListController selectedObjects] lastObject];
	if (filterSet != nil)
		[self setSettingForClientApplication:[filterSet objectForKey:@"uid"] forKey:@"selectedFilterSet"];
}

- (void)restoreClientApplicationSettings
{
	NSDictionary *clientAppSettings = [self settingsForClientApplication];
	if (clientAppSettings == nil)
		return;

	clientAppSettingsRestored = YES;

	// when an application connects, we restore some saved settings so the user
	// comes back to about the same configuration she was using the last time
	id showFuncs = [clientAppSettings objectForKey:@"showFunctionNames"];
	if (showFuncs != nil)
		[self setShowFunctionNames:showFuncs];
	
	// try to restore the last filter set that was
	// selected for this application. Usually, you have a filter set per application
	// (this is how it is intended to be used), so it makes sense to preselect it
	// when the application connects.
	NSNumber *filterSetUID = [clientAppSettings objectForKey:@"selectedFilterSet"];
	if (filterSetUID != nil)
	{
		// try retrieving the filter set
		NSArray *matchingFilters = [[filterSetsListController arrangedObjects] filteredArrayUsingPredicate:
									[NSPredicate predicateWithFormat:@"uid == %@", filterSetUID]];
		if ([matchingFilters count] == 1)
			[filterSetsListController setSelectedObjects:matchingFilters];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Splitview delegate
// -----------------------------------------------------------------------------
- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
//	tableNeedsTiling = YES;
}

//- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
//    if (sender == splitView) {
//        NSSize newSize = sender.bounds.size;
//        
//        NSView *mainDisplay = [[sender subviews] objectAtIndex:1];
//        NSRect frame = mainDisplay.frame;
//        frame.size.width += newSize.width - oldSize.width;
//        frame.size.height = newSize.height;
//        [mainDisplay setFrame:frame];
//        
//        NSView *sidebar = [[sender subviews] objectAtIndex:0];
//        NSRect sidebarFrame = sidebar.frame;
//        sidebarFrame.size.height = newSize.height;
//        [sidebar setFrame:sidebarFrame];
//    } else {
//        [sender adjustSubviews];
//    }
//}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Window delegate
// -----------------------------------------------------------------------------
- (void)windowDidResize:(NSNotification *)notification
{
	if (![[self window] inLiveResize])
		[self tileLogTable:NO];
}

- (void)windowDidEndLiveResize:(NSNotification *)notification
{
	[self tileLogTable:NO];
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[self updateMenuBar:YES];

	NSColor *bgColor = [NSColor colorWithCalibratedRed:(218.0 / 255.0)
												 green:(221.0 / 255.0)
												  blue:(229.0 / 255.0)
												 alpha:1.0f];
	[filterSetsTable setBackgroundColor:bgColor];
	[filterTable setBackgroundColor:bgColor];
}

- (void)windowDidResignMain:(NSNotification *)notification
{
	[self updateMenuBar:NO];

	// constants by Brandon Walkin
	NSColor *bgColor = [NSColor colorWithCalibratedRed:(234.0 / 255.0)
												 green:(234.0 / 255.0)
												  blue:(234.0 / 255.0)
												 alpha:1.0f];
	[filterSetsTable setBackgroundColor:bgColor];
	[filterTable setBackgroundColor:bgColor];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Quick filter
// -----------------------------------------------------------------------------
- (void)rebuildQuickFilterPopup
{
	NSMenu *menu = [quickFilter menu];
	
	// remove all tags
	while ([[menu itemAtIndex:[menu numberOfItems]-1] tag] != -1)
		[menu removeItemAtIndex:[menu numberOfItems]-1];

	// set selected level checkmark
	NSString *levelTitle = nil;
	for (NSMenuItem *menuItem in [menu itemArray])
	{
		if ([menuItem isSeparatorItem])
			continue;
		if ([menuItem tag] == logLevel)
		{
			[menuItem setState:NSOnState];
			levelTitle = [menuItem title];
		}
		else
			[menuItem setState:NSOffState];
	}

	NSString *tagTitle;
	NSMenuItem *item = [[menu itemArray] lastObject];
	if (filterTags.count == 0)
	{
		[item setState:NSOnState];
		tagTitle = [item title];
	}
	else
	{
		[item setState:NSOffState];
		tagTitle = [NSString stringWithFormat:NSLocalizedString(@"Tag%@: %@", @""), filterTags.count > 1 ? @"s" : @"", [filterTags.allObjects componentsJoinedByString:@","]];
	}

	for (NSString *tag in [[tags allObjects] sortedArrayUsingSelector:@selector(localizedCompare:)])
	{
		item = [[NSMenuItem alloc] initWithTitle:tag action:@selector(selectQuickFilterTag:) keyEquivalent:@""];
		[item setRepresentedObject:tag];
		[item setIndentationLevel:1];
		if ([filterTags containsObject:tag])
			[item setState:NSOnState];
		[menu addItem:item];
		[item release];
	}

	[quickFilter setTitle:[NSString stringWithFormat:@"%@ | %@", levelTitle, tagTitle]];
	
	self.hasQuickFilter = (filterString != nil || filterTags.count != 0 || logLevel != 0);
}

- (void)addTags:(NSArray *)newTags
{
	// complete the set of "seen" tags in messages
	// if changed, update the quick filter popup
	NSUInteger numTags = [tags count];
	[tags addObjectsFromArray:newTags];
	if ([tags count] != numTags)
		[self rebuildQuickFilterPopup];
}

- (IBAction)selectQuickFilterTag:(id)sender
{
	NSString *newTag = [sender representedObject];

	// Selected All Tags
	if (newTag.length == 0) {
		[filterTags removeAllObjects];
	}
	// Selected Specific Tag
	else {
		// Determine if Options key was pressed
		NSUInteger flags = [[NSApp currentEvent] modifierFlags];
		BOOL hasOptionKeyPressed = (flags & NSEventModifierFlagOption) != 0;

		// Clear multiple selection or single selection with different tag
		if (!hasOptionKeyPressed && (filterTags.count != 1 || ![filterTags containsObject:newTag])) {
			[filterTags removeAllObjects];
		}

		// Toggle tag
		if ([filterTags containsObject:newTag]) {
			[filterTags removeObject:newTag];
		} else {
			[filterTags addObject:newTag];
		}
	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
	[self performSelector:@selector(refreshMessagesIfPredicateChanged) withObject:nil afterDelay:0];
}

- (IBAction)selectQuickFilterLevel:(id)sender
{
	int level = [(NSView *)sender tag];
	if (level != logLevel)
	{
		logLevel = level;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
		[self performSelector:@selector(refreshMessagesIfPredicateChanged) withObject:nil afterDelay:0];
	}
}

- (IBAction)resetQuickFilter:(id)sender
{
	[filterString release];
	filterString = @"";
	[filterTags removeAllObjects];
	logLevel = 0;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
	[self performSelector:@selector(refreshMessagesIfPredicateChanged) withObject:nil afterDelay:0];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Table management
// -----------------------------------------------------------------------------
- (void)messagesAppendedToTable
{
	assert([NSThread isMainThread]);
	if (attachedConnection.connected)
	{
		NSRect r = [[logTable superview] convertRect:[[logTable superview] bounds] toView:logTable];
		NSRange visibleRows = [logTable rowsInRect:r];
		BOOL lastVisible = (visibleRows.location == NSNotFound ||
							visibleRows.length == 0 ||
							(visibleRows.location + visibleRows.length) >= lastMessageRow);
		[logTable noteNumberOfRowsChanged];
		if (lastVisible)
			[logTable scrollRowToVisible:[displayedMessages count] - 1];
	}
	else
	{
		[logTable noteNumberOfRowsChanged];
	}
	lastMessageRow = [displayedMessages count];
	self.info = [NSString stringWithFormat:NSLocalizedString(@"%u messages", @""), [displayedMessages count]];
}

- (void)appendMessagesToTable:(NSArray *)messages
{
	assert([NSThread isMainThread]);
	[displayedMessages addObjectsFromArray:messages];

	// schedule a table reload. Do this asynchronously (and cancellable-y) so we can limit the
	// number of reload requests in case of high load
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(messagesAppendedToTable) object:nil];
	[self performSelector:@selector(messagesAppendedToTable) withObject:nil afterDelay:0];
}

- (IBAction)openDetailsWindow:(id)sender
{
	// open a details view window for the selected messages
	if (detailsWindowController == nil)
	{
		detailsWindowController = [[LoggerDetailsWindowController alloc] initWithWindowNibName:@"LoggerDetailsWindow"];
		[detailsWindowController window];	// force window to load
		[[self document] addWindowController:detailsWindowController];
	}
	[detailsWindowController setMessages:[displayedMessages objectsAtIndexes:[logTable selectedRowIndexes]]];
	[detailsWindowController showWindow:self];
}

void runSystemCommand(NSString *cmd)
{
    [[NSTask launchedTaskWithLaunchPath:@"/bin/sh"
                              arguments:[NSArray arrayWithObjects:@"-c", cmd, nil]] waitUntilExit];
}

- (IBAction)openDetailsInExternalEditor:(id)sender
{
    NSArray *msgs = [displayedMessages objectsAtIndexes:[logTable selectedRowIndexes]];
    NSString *txtMsg = [[msgs lastObject] textRepresentation];

    NSString *globallyUniqueStr = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:globallyUniqueStr];

    [txtMsg writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSString *cmd = [NSString stringWithFormat:@"open -t %@", tempPath];
    runSystemCommand(cmd);
}

- (void)openDetailsInIDE
{
	NSInteger row = [logTable selectedRow];
	if (row >= 0 && row < [displayedMessages count])
	{
		LoggerMessage *msg = [displayedMessages objectAtIndex:row];
		NSString *filename = msg.filename;
		if ([filename length])
		{
			NSFileManager *fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:filename])
			{
				// If the file is .h, .m, .c, .cpp, .h, .hpp: open the file
				// using xed. Otherwise, open the file with the Finder. We really don't
				// know which IDE the user is running if it's not Xcode
				// (when logging from Android, could be IntelliJ or Eclipse)
				NSString *extension = [filename pathExtension];
				BOOL useXcode = NO;
				for (NSString *ext in sXcodeFileExtensions)
				{
					if ([ext caseInsensitiveCompare:extension] == NSOrderedSame)
					{
						useXcode = YES;
						break;
					}
				}
				if (useXcode)
				{
					OpenFileInXcode(filename, MAX(0, msg.lineNumber));
				}
				else
				{
					[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:filename]];
				}
			}
		}
	}
}

- (void)logCellDoubleClicked:(id)sender
{
    // double click opens the selection in the detail view
	// command-double click opens the source file if it was defined in the log and the file is found (using alt can mess with the results of the AppleScript)
	// alt-doubleclick opens the selection in external editor
	NSEvent *event = [NSApp currentEvent];
    if ([event clickCount] > 1 && ([NSEvent modifierFlags] & (NSFunctionKeyMask | NSCommandKeyMask)) != 0)
    {
		[self openDetailsInIDE];
    }
    else if ([event clickCount] > 1 && ([NSEvent modifierFlags] & NSAlternateKeyMask) != 0)
    {
        [self openDetailsInExternalEditor:sender];
    }
    else if ([event clickCount] > 1)
    {
        [self openDetailsWindow:sender];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Filtering
// -----------------------------------------------------------------------------
- (void)refreshAllMessages:(NSArray *)selectedMessages
{
	assert([NSThread isMainThread]);
	@synchronized (attachedConnection.messages)
	{
		BOOL quickFilterWasFirstResponder = ([[self window] firstResponder] == [quickFilterTextField currentEditor]);
		id messageToMakeVisible = [selectedMessages objectAtIndex:0];
		if (messageToMakeVisible == nil)
		{
			// Remember the currently selected messages
			NSIndexSet *selectedRows = [logTable selectedRowIndexes];
			if ([selectedRows count])
				selectedMessages = [displayedMessages objectsAtIndexes:selectedRows];

			NSRect r = [[logTable superview] convertRect:[[logTable superview] bounds] toView:logTable];
			NSRange visibleRows = [logTable rowsInRect:r];
			if (visibleRows.length != 0)
			{
				NSIndexSet *selectedVisible = [selectedRows indexesInRange:visibleRows options:0 passingTest:^(NSUInteger idx, BOOL *stop){return YES;}];
				if ([selectedVisible count])
					messageToMakeVisible = [displayedMessages objectAtIndex:[selectedVisible firstIndex]];
				else
					messageToMakeVisible = [displayedMessages objectAtIndex:visibleRows.location];
			}
		}

		LoggerConnection *theConnection = attachedConnection;

		NSSize tableFrameSize = [logTable frame].size;
		NSUInteger numMessages = [attachedConnection.messages count];
		for (int i = 0; i < numMessages;)
		{
			if (i == 0)
			{
				dispatch_async(messageFilteringQueue, ^{
					dispatch_async(dispatch_get_main_queue(), ^{
						lastMessageRow = 0;
						[displayedMessages removeAllObjects];
						[logTable reloadData];
						self.info = NSLocalizedString(@"No message", @"");
					});
				});
			}
			NSUInteger length = MIN(4096, numMessages - i);
			if (length)
			{
				NSPredicate *aFilter = filterPredicate;
				NSArray *subArray = [attachedConnection.messages subarrayWithRange:NSMakeRange(i, length)];
				dispatch_async(messageFilteringQueue, ^{
					// Check that the connection didn't change
					if (attachedConnection == theConnection)
						[self filterIncomingMessages:subArray withFilter:aFilter tableFrameSize:tableFrameSize];
				});
			}
			i += length;
		}

		// Stuff we want to do only when filtering is complete. To do this, we enqueue
		// one more operation to the message filtering queue, with the only goal of
		// being executed only at the end of the filtering process
		dispatch_async(messageFilteringQueue, ^{
			dispatch_async(dispatch_get_main_queue(), ^{
				// if the connection changed since the last refreshAll call, stop now
				if (attachedConnection == theConnection)		// note that block retains self, not self.attachedConnection.
				{
					if (lastMessageRow < [displayedMessages count])
					{
						// perform table updates now, so we can properly reselect afterwards
						[NSObject cancelPreviousPerformRequestsWithTarget:self
																 selector:@selector(messagesAppendedToTable)
																   object:nil];
						[self messagesAppendedToTable];
					}
					
					if ([selectedMessages count])
					{
						// If there were selected rows, try to reselect them
						NSMutableIndexSet *newSelectionIndexes = [[NSMutableIndexSet alloc] init];
						for (id msg in selectedMessages)
						{
							NSInteger msgIndex = [displayedMessages indexOfObjectIdenticalTo:msg];
							if (msgIndex != NSNotFound)
								[newSelectionIndexes addIndex:(NSUInteger)msgIndex];
						}
						if ([newSelectionIndexes count])
						{
							[logTable selectRowIndexes:newSelectionIndexes byExtendingSelection:NO];
							if (!quickFilterWasFirstResponder)
								[[self window] makeFirstResponder:logTable];
						}
						[newSelectionIndexes release];
					}
					
					if (messageToMakeVisible != nil)
					{
						// Restore the logical location in the message flow, to keep the user
						// in-context
						NSUInteger msgIndex;
						id msg = messageToMakeVisible;
						@synchronized(attachedConnection.messages)
						{
							while ((msgIndex = [displayedMessages indexOfObjectIdenticalTo:msg]) == NSNotFound)
							{
								NSUInteger where = [attachedConnection.messages indexOfObjectIdenticalTo:msg];
								if (where == NSNotFound)
									break;
								if (where == 0)
								{
									msgIndex = 0;
									break;
								}
								else
									msg = [attachedConnection.messages objectAtIndex:where-1];
							}
							if (msgIndex != NSNotFound)
								[logTable scrollRowToVisible:msgIndex];
						}
					}
					
					[self rebuildMarksSubmenu];
				}
				initialRefreshDone = YES;
			});
		});
	}
}

- (void)filterIncomingMessages:(NSArray *)messages
{
	assert([NSThread isMainThread]);
	NSPredicate *aFilter = [filterPredicate retain];		// catch value now rather than dereference it from self later
	NSSize tableFrameSize = [logTable frame].size;
	dispatch_async(messageFilteringQueue, ^{
		[self filterIncomingMessages:(NSArray *)messages withFilter:aFilter tableFrameSize:tableFrameSize];
		[aFilter release];
	});
}

- (void)filterIncomingMessages:(NSArray *)messages
					withFilter:(NSPredicate *)aFilter
				tableFrameSize:(NSSize)tableFrameSize
{
	// collect all tags
	NSArray *msgTags = [messages valueForKeyPath:@"@distinctUnionOfObjects.tag"];

	// find out which messages we want to keep. Executed on the message filtering queue
	NSArray *filteredMessages = [messages filteredArrayUsingPredicate:aFilter];
	if ([filteredMessages count])
	{
		[self tileLogTableMessages:filteredMessages withSize:tableFrameSize forceUpdate:NO group:NULL];
		LoggerConnection *theConnection = attachedConnection;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (attachedConnection == theConnection)
			{
				[self appendMessagesToTable:filteredMessages];
				[self addTags:msgTags];
			}
		});
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties and bindings
// -----------------------------------------------------------------------------
- (void)setAttachedConnection:(LoggerConnection *)aConnection
{
	assert([NSThread isMainThread]);

	if (attachedConnection != nil)
	{
		// Completely clear log table
		[logTable deselectAll:self];
		lastMessageRow = 0;
		[displayedMessages removeAllObjects];
		self.info = NSLocalizedString(@"No message", @"");
		[logTable reloadData];
		[self rebuildMarksSubmenu];

		// Close filter editor sheet (with cancel) if open
		if ([filterEditorWindow isVisible])
			[NSApp endSheet:filterEditorWindow returnCode:0];

		// Cancel pending tasks
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshAllMessages:) object:nil];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(messagesAppendedToTable) object:nil];
		if (lastTilingGroup != NULL)
		{
			dispatch_set_context(lastTilingGroup, NULL);
			dispatch_release(lastTilingGroup);
			lastTilingGroup = NULL;
		}
		
		// Detach previous connection
		attachedConnection.attachedToWindow = NO;
		[attachedConnection release];
		attachedConnection = nil;
	}
	if (aConnection != nil)
	{
		attachedConnection = [aConnection retain];
		attachedConnection.attachedToWindow = YES;
		//dispatch_async(dispatch_get_main_queue(), ^{
			initialRefreshDone = NO;
			[self updateClientInfo];
			if (!clientAppSettingsRestored)
				[self restoreClientApplicationSettings];
			[self rebuildRunsSubmenu];
			[self refreshAllMessages:nil];
		//});
	}
}

- (NSNumber *)shouldEnableRunsPopup
{
	NSUInteger numRuns = [((LoggerDocument *)[self document]).attachedLogs count];
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kPrefKeepMultipleRuns] && numRuns <= 1)
		return (id)kCFBooleanFalse;
	return (id)kCFBooleanTrue;
}

- (void)setFilterString:(NSString *)newString
{
	if (newString == nil)
		newString = @"";

	if (newString != filterString && ![filterString isEqualToString:newString])
	{
		[filterString autorelease];
		filterString = [newString copy];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
		[self performSelector:@selector(refreshMessagesIfPredicateChanged) withObject:nil afterDelay:0];
		self.hasQuickFilter = (filterString != nil || filterTags.count != 0 || logLevel != 0);
	}
}

- (void)setShowFunctionNames:(NSNumber *)value
{
	BOOL b = [value boolValue];
	if (b != showFunctionNames)
	{
		[self willChangeValueForKey:@"showFunctionNames"];
		showFunctionNames = b;
		[self tileLogTable:YES];
		dispatch_async(dispatch_get_main_queue(), ^{
			[logTable reloadData];
		});
		[self didChangeValueForKey:@"showFunctionNames"];

		dispatch_async(dispatch_get_main_queue(), ^{
			[self setSettingForClientApplication:value forKey:@"showFunctionNames"];
		});
	}
}

- (NSNumber *)showFunctionNames
{
	return [NSNumber numberWithBool:showFunctionNames];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark LoggerConnectionDelegate
// -----------------------------------------------------------------------------
- (void)connection:(LoggerConnection *)theConnection
didReceiveMessages:(NSArray *)theMessages
			 range:(NSRange)rangeInMessagesList
{
	// We need to hop thru the main thread to have a recent and stable copy of the filter string and current filter
	dispatch_async(dispatch_get_main_queue(), ^{
		if (initialRefreshDone)
			[self filterIncomingMessages:theMessages];
	});
}

- (void)remoteDisconnected:(LoggerConnection *)theConnection
{
	// we always get called on the main thread
	[self updateClientInfo];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark KVO / Bindings
// -----------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == attachedConnection)
	{
		if ([keyPath isEqualToString:@"clientIDReceived"])
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateClientInfo];
				if (!clientAppSettingsRestored)
					[self restoreClientApplicationSettings];
			});			
		}
	}
	else if (object == filterListController)
	{
		if ([keyPath isEqualToString:@"selectedObjects"])
		{
			if ([filterListController selectionIndex] != NSNotFound)
			{
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMessagesIfPredicateChanged) object:nil];
				[self performSelector:@selector(refreshMessagesIfPredicateChanged) withObject:nil afterDelay:0];
			}
		}
	}
	else if (object == filterSetsListController)
	{
		if ([keyPath isEqualToString:@"arrangedObjects"])
		{
			// we'll be called when arrangedObjects change, that is when a filter set is added,
			// removed or renamed. Use this occasion to save the filters definition.
			[(LoggerAppDelegate *)[NSApp delegate] saveFiltersDefinition];
		}
		else if ([keyPath isEqualToString:@"selectedObjects"])
		{
			[self rememberFiltersSelection];
		}
	} else if (object == [NSUserDefaults standardUserDefaults])
    {
        if ([keyPath isEqualToString:kMaxTableRowHeight])
        {
            [self tileLogTable:YES];
        }
    }
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark NSTableDelegate
// -----------------------------------------------------------------------------
- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (tableView == logTable && row >= 0 && row < [displayedMessages count])
	{
		LoggerMessage *msg = [displayedMessages objectAtIndex:row];
		switch (msg.type)
		{
			case LOGMSG_TYPE_LOG:
			case LOGMSG_TYPE_BLOCKSTART:
			case LOGMSG_TYPE_BLOCKEND:
				return messageCell;
			case LOGMSG_TYPE_CLIENTINFO:
			case LOGMSG_TYPE_DISCONNECT:
				return clientInfoCell;
			case LOGMSG_TYPE_MARK:
				return markerCell;
			default:
				assert(false);
				break;
		}
	}
	return nil;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == logTable && rowIndex >= 0 && rowIndex < [displayedMessages count])
	{
		// setup the message to be displayed
		LoggerMessageCell *cell = (LoggerMessageCell *)aCell;
		cell.message = [displayedMessages objectAtIndex:rowIndex];
		cell.shouldShowFunctionNames = showFunctionNames;

		// if previous message is a Mark, go back a bit more to get the real previous message
		// if previous message is ClientInfo, don't use it.
		NSInteger idx = rowIndex - 1;
		LoggerMessage *prev = nil;
		while (prev == nil && idx >= 0)
		{
			prev = [displayedMessages objectAtIndex:idx--];
			if (prev.type == LOGMSG_TYPE_CLIENTINFO || prev.type == LOGMSG_TYPE_MARK)
				prev = nil;
		} 
		
		cell.previousMessage = prev;
	}
	else if (aTableView == filterSetsTable)
	{
		NSArray *filterSetsList = [filterSetsListController arrangedObjects];
		if (rowIndex >= 0 && rowIndex < [filterSetsList count])
		{
			NSTextFieldCell *tc = (NSTextFieldCell *)aCell;
			NSDictionary *filterSet = [filterSetsList objectAtIndex:rowIndex];
			if ([[filterSet objectForKey:@"uid"] integerValue] == 1)
				[tc setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
			else
				[tc setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		}
	}
	else if (aTableView == filterTable)
	{
		// want the "All Logs" entry (immutable) in Bold
		NSArray *filterList = [filterListController arrangedObjects];
		if (rowIndex >= 0 && rowIndex < [filterList count])
		{
			NSTextFieldCell *tc = (NSTextFieldCell *)aCell;
			NSDictionary *filter = [filterList objectAtIndex:rowIndex];
			if ([[filter objectForKey:@"uid"] integerValue] == 1)
				[tc setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
			else
				[tc setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		}
	}
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	assert([NSThread isMainThread]);
	if (tableView == logTable && row >= 0 && row < [displayedMessages count])
	{
		// use only cached sizes
		LoggerMessage *message = [displayedMessages objectAtIndex:row];
		NSSize cachedSize = message.cachedCellSize;
		if (cachedSize.height)
			return cachedSize.height;
	}
	return [tableView rowHeight];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == logTable)
	{
		self.messagesSelected = ([logTable selectedRow] >= 0);
		if (messagesSelected && detailsWindowController != nil && [[detailsWindowController window] isVisible])
			[detailsWindowController setMessages:[displayedMessages objectsAtIndexes:[logTable selectedRowIndexes]]];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark NSTableDataSource
// -----------------------------------------------------------------------------
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [displayedMessages count];
}

- (id)tableView:(NSTableView *)tableView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
	row:(NSInteger)rowIndex
{
	if (rowIndex >= 0 && rowIndex < [displayedMessages count])
		return [displayedMessages objectAtIndex:rowIndex];
	return nil;
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	if (tv == logTable)
	{
		NSArray *draggedMessages = [displayedMessages objectsAtIndexes:rowIndexes];
		NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[draggedMessages count] * 128];
		for (LoggerMessage *msg in draggedMessages)
			[string appendString:[msg textRepresentation]];
		[pboard writeObjects:[NSArray arrayWithObject:string]];
		[string release];
		return YES;
	}
	if (tv == filterTable)
	{
		NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
		NSArray *filters = [[filterListController arrangedObjects] objectsAtIndexes:rowIndexes];
		[item setData:[NSKeyedArchiver archivedDataWithRootObject:filters] forType:kNSLoggerFilterPasteboardType];
		[pboard writeObjects:[NSArray arrayWithObject:item]];
		[item release];
		return YES;
	}
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)dragInfo proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
	if (tv == filterSetsTable)
	{
		NSArray *filterSets = [filterSetsListController arrangedObjects];
		if (row >= 0 && row < [filterSets count] && row != [filterSetsListController selectionIndex])
		{
			if (op != NSTableViewDropOn)
				[filterSetsTable setDropRow:row dropOperation:NSTableViewDropOn];
			return NSDragOperationCopy;
		}
	}
	else if (tv == filterTable && [dragInfo draggingSource] != filterTable)
	{
		NSArray *filters = [filterListController arrangedObjects];
		if (row >= 0 && row < [filters count])
		{
			// highlight entire table
			[filterTable setDropRow:-1 dropOperation:NSTableViewDropOn];
			return NSDragOperationCopy;
		}
	}
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv
	   acceptDrop:(id <NSDraggingInfo>)dragInfo
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
	BOOL added = NO;
	NSPasteboard* pboard = [dragInfo draggingPasteboard];
	NSArray *newFilters = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:kNSLoggerFilterPasteboardType]];
	if (tv == filterSetsTable)
	{
		// Only add those filters which don't exist yet
		NSArray *filterSets = [filterSetsListController arrangedObjects];
		NSMutableDictionary *filterSet = [filterSets objectAtIndex:row];
		NSMutableArray *existingFilters = [filterSet mutableArrayValueForKey:@"filters"];
		for (NSMutableDictionary *filter in newFilters)
		{
			if ([existingFilters indexOfObject:filter] == NSNotFound)
			{
				[existingFilters addObject:filter];
				added = YES;
			}
		}
		[filterSetsListController setSelectedObjects:[NSArray arrayWithObject:filterSet]];
	}
	else if (tv == filterTable)
	{
		NSMutableArray *addedFilters = [[NSMutableArray alloc] init];
		for (NSMutableDictionary *filter in newFilters)
		{
			if ([[filterListController arrangedObjects] indexOfObject:filter] == NSNotFound)
			{
				[filterListController addObject:filter];
				[addedFilters addObject:filter];
				added = YES;
			}
		}
		if (added)
			[filterListController setSelectedObjects:addedFilters];
		[addedFilters release];
	}
	if (added)
		[(LoggerAppDelegate *)[NSApp delegate] saveFiltersDefinition];
	return added;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Filter sets management
// -----------------------------------------------------------------------------
- (void)undoableAddFilterSet:(id)set
{
	NSUndoManager *um = [self undoManager];
	[um registerUndoWithTarget:self selector:_cmd object:set];
	[um setActionName:NSLocalizedString(@"Add Application Set", @"")];
	if ([um isUndoing])
		[filterSetsListController removeObject:set];
	else
	{
		[filterSetsListController addObject:set];
		if (![um isRedoing])
		{
			NSUInteger index = [[filterSetsListController arrangedObjects] indexOfObject:set];
			[filterSetsTable editColumn:0 row:index withEvent:nil select:YES];
		}
	}
}

- (void)undoableDeleteFilterSet:(id)set
{
	NSUndoManager *um = [self undoManager];
	[um registerUndoWithTarget:self selector:_cmd object:set];
	[um setActionName:NSLocalizedString(@"Delete Application Set", @"")];
	if ([um isUndoing])
		[filterSetsListController addObjects:set];
	else
		[filterSetsListController removeObjects:set];
}

- (IBAction)addFilterSet:(id)sender
{
	id dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			   [(LoggerAppDelegate *)[NSApp delegate] nextUniqueFilterIdentifier:[filterSetsListController arrangedObjects]], @"uid",
			   NSLocalizedString(@"New App. Set", @""), @"title",
			   [(LoggerAppDelegate *)[NSApp delegate] defaultFilters], @"filters",
			   nil];
	[self undoableAddFilterSet:dict];
}

- (IBAction)deleteSelectedFilterSet:(id)sender
{
	[self undoableDeleteFilterSet:[filterSetsListController selectedObjects]];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Filter editor
// -----------------------------------------------------------------------------
- (void)undoableModifyFilter:(NSDictionary *)filter
{
	NSMutableDictionary *previousFilter = nil;
	for (NSMutableDictionary *dict in [filterListController content])
	{
		if ([[dict objectForKey:@"uid"] isEqual:[filter objectForKey:@"uid"]])
		{
			previousFilter = dict;
			break;
		}
	}
	assert(previousFilter != nil);
	[[self undoManager] registerUndoWithTarget:self selector:_cmd object:[[previousFilter mutableCopy] autorelease]];
	[[self undoManager] setActionName:NSLocalizedString(@"Modify Filter", @"")];
	[previousFilter addEntriesFromDictionary:filter];
	[filterListController setSelectedObjects:[NSArray arrayWithObject:previousFilter]];
}

- (void)undoableCreateFilter:(NSDictionary *)filter
{
	NSUndoManager *um = [self undoManager];
	[um registerUndoWithTarget:self selector:_cmd object:filter];
	[um setActionName:NSLocalizedString(@"Create Filter", @"")];
	if ([um isUndoing])
		[filterListController removeObject:filter];
	else
	{
		[filterListController addObject:filter];
		[filterListController setSelectedObjects:[NSArray arrayWithObject:filter]];
	}
}

- (void)undoableDeleteFilters:(NSArray *)filters
{
	NSUndoManager *um = [self undoManager];
	[um registerUndoWithTarget:self selector:_cmd object:filters];
	[um setActionName:NSLocalizedString(@"Delete Filters", @"")];
	if ([um isUndoing])
	{
		[filterListController addObjects:filters];
		[filterListController setSelectedObjects:filters];
	}
	else
		[filterListController removeObjects:filters];
}

- (void)openFilterEditSheet:(NSDictionary *)dict
{
	[filterName setStringValue:[dict objectForKey:@"title"]];
	NSPredicate *predicate = [dict objectForKey:@"predicate"];
	[filterEditor setObjectValue:[[predicate copy] autorelease]];
	
	[NSApp beginSheet:filterEditorWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(filterEditSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[dict retain]];	
}

- (void)filterEditSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode)
	{
		NSMutableDictionary *dict = [[(NSDictionary *)contextInfo mutableCopy] autorelease];
		BOOL exists = [[filterListController content] containsObject:(id)contextInfo];
		
		NSPredicate *predicate = [filterEditor predicate];
		if (predicate == nil)
			predicate = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray array]];
		[dict setObject:predicate forKey:@"predicate"];
		
		NSString *title = [[filterName stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if ([title length])
			[dict setObject:title forKey:@"title"];
		
		if (exists)
			[self undoableModifyFilter:dict];
		else
			[self undoableCreateFilter:dict];
		
		[filterListController setSelectedObjects:[NSArray arrayWithObject:dict]];
		
		[(LoggerAppDelegate *)[NSApp delegate] saveFiltersDefinition];
	}
	[(id)contextInfo release];
	[filterEditorWindow orderOut:self];
}

- (IBAction)deleteSelectedFilters:(id)sender
{
	[self undoableDeleteFilters:[filterListController selectedObjects]];
}

- (IBAction)addFilter:(id)sender
{
	NSDictionary *filterSet = [[filterSetsListController selectedObjects] lastObject];
	assert(filterSet != nil);
	NSDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						  [(LoggerAppDelegate *)[NSApp delegate] nextUniqueFilterIdentifier:[filterSet objectForKey:@"filters"]], @"uid",
						  NSLocalizedString(@"New filter", @""), @"title",
						  [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray array]], @"predicate",
						  nil];
	[self openFilterEditSheet:dict];
	[filterEditor addRow:self];
}

- (IBAction)startEditingFilter:(id)sender
{
	// start editing filter, unless no selection (happens when double-clicking the header)
	// or when trying to edit the "All Logs" entry which is immutable
	NSDictionary *dict = [[filterListController selectedObjects] lastObject];
	if (dict == nil || [[dict objectForKey:@"uid"] integerValue] == 1)
		return;
	[self openFilterEditSheet:dict];
	
}

- (IBAction)cancelFilterEdition:(id)sender
{
	[NSApp endSheet:filterEditorWindow returnCode:0];
}

- (IBAction)validateFilterEdition:(id)sender
{
	[NSApp endSheet:filterEditorWindow returnCode:1];
}


- (IBAction)createNewFilterFromQuickFilter:(id) sender
{
	NSDictionary *filterSet = [[filterSetsListController selectedObjects] lastObject];
	assert(filterSet != nil);
	
	NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:3];
	NSString *newFilterTitle;
	
	if ([filterString length])
	{
		[predicates addObject:[NSPredicate predicateWithFormat:@"messageText contains %@", filterString]];
		newFilterTitle = [NSString stringWithFormat:NSLocalizedString(@"Quick Filter: %@", @""), filterString];
	}
	else
		newFilterTitle = NSLocalizedString(@"Quick Filter", @"");
	
	if (logLevel)
		[predicates addObject:[NSPredicate predicateWithFormat:@"level <= %d", logLevel - 1]];

	if (self.filterTags.count > 0) {
		NSMutableArray *filterTagsPredicates = [[NSMutableArray alloc] initWithCapacity:self.filterTags.count];
		for (NSString *filterTag in self.filterTags) {
			[filterTagsPredicates addObject:[NSPredicate predicateWithFormat:@"tag = %@", filterTag]];
		}
		[predicates addObject:[NSCompoundPredicate orPredicateWithSubpredicates:filterTagsPredicates]];
		[filterTagsPredicates release];
	}
	
	NSDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						  [(LoggerAppDelegate *)[NSApp delegate] nextUniqueFilterIdentifier:[filterSet objectForKey:@"filters"]], @"uid",
						  newFilterTitle, @"title",
						  [NSCompoundPredicate andPredicateWithSubpredicates:predicates], @"predicate",
						  nil];
	[self openFilterEditSheet:dict];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Markers
// -----------------------------------------------------------------------------
- (void)rebuildMarksSubmenu
{
	NSMenuItem *marksSubmenu = [[[[NSApp mainMenu] itemWithTag:TOOLS_MENU_ITEM_TAG] submenu] itemWithTag:TOOLS_MENU_JUMP_TO_MARK_TAG];
	NSExpression *lhs = [NSExpression expressionForKeyPath:@"type"];
	NSExpression *rhs = [NSExpression expressionForConstantValue:[NSNumber numberWithInteger:LOGMSG_TYPE_MARK]];
	NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression:lhs
																rightExpression:rhs
																	   modifier:NSDirectPredicateModifier
																		   type:NSEqualToPredicateOperatorType
																		options:0];
	NSArray *marks = [displayedMessages filteredArrayUsingPredicate:predicate];
	NSMenu *menu = [marksSubmenu submenu];
	[menu removeAllItems];
	if (![marks count])
	{
		NSMenuItem *noMarkItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Mark", @"")
															action:nil
													 keyEquivalent:@""];
		[noMarkItem setEnabled:NO];
		[menu addItem:noMarkItem];
		[noMarkItem release];
	}
	else for (LoggerMessage *mark in marks)
	{
		NSMenuItem *markItem = [[NSMenuItem alloc] initWithTitle:mark.message ?: @""
														  action:@selector(jumpToMark:)
												   keyEquivalent:@""];
		[markItem setRepresentedObject:mark];
		[markItem setTarget:self];
		[menu addItem:markItem];
		[markItem release];
	}
}

- (void)clearMarksSubmenu
{
	NSMenuItem *marksSubmenu = [[[[NSApp mainMenu] itemWithTag:TOOLS_MENU_ITEM_TAG] submenu] itemWithTag:TOOLS_MENU_JUMP_TO_MARK_TAG];
	NSMenu *menu = [marksSubmenu submenu];
	[menu removeAllItems];
	NSMenuItem *dummyItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Mark", @"") action:nil keyEquivalent:@""];
	[dummyItem setEnabled:NO];
	[menu addItem:dummyItem];
	[dummyItem release];
}

- (void)jumpToMark:(NSMenuItem *)markMenuItem
{
	LoggerMessage *mark = [markMenuItem representedObject];
	NSUInteger idx = [displayedMessages indexOfObjectIdenticalTo:mark];
	if (idx == NSNotFound)
	{
		// actually, shouldn't happen
		NSBeep();
	}
	else
	{
		[logTable scrollRowToVisible:idx];
		[logTable selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
		[self.window makeMainWindow];
	}
}

- (void)addMarkWithTitleString:(NSString *)title beforeMessage:(LoggerMessage *)beforeMessage
{
	if (![title length])
	{
		title = [NSString stringWithFormat:NSLocalizedString(@"Mark - %@", @""),
				 [NSDateFormatter localizedStringFromDate:[NSDate date]
												dateStyle:NSDateFormatterShortStyle
												timeStyle:NSDateFormatterMediumStyle]];
	}
	
	LoggerMessage *mark = [[LoggerMessage alloc] init];
	struct timeval tv;
	gettimeofday(&tv, NULL);
	mark.type = LOGMSG_TYPE_MARK;
	mark.timestamp = tv;
	mark.message = title;
	mark.threadID = @"";
	mark.contentsType = kMessageString;
	
	// we want to process the mark after all current scheduled filtering operations
	// (including refresh All) are done
	dispatch_async(messageFilteringQueue, ^{
		// then we serialize all operations modifying the messages list in the connection's
		// message processing queue
		dispatch_async(attachedConnection.messageProcessingQueue, ^{
			NSRange range;
			@synchronized(attachedConnection.messages)
			{
				range.location = [attachedConnection.messages count];
				range.length = 1;
				if (beforeMessage != nil)
				{
					NSUInteger pos = [attachedConnection.messages indexOfObjectIdenticalTo:beforeMessage];
					if (pos != NSNotFound)
						range.location = pos;
				}
				[attachedConnection.messages insertObject:mark atIndex:range.location];
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				[[self document] updateChangeCount:NSChangeDone];
				[self refreshAllMessages:[NSArray arrayWithObjects:mark, beforeMessage, nil]];
			});
		});
	});

	[mark release];
}

- (void)addMarkWithTitleBeforeMessage:(LoggerMessage *)aMessage
{
	NSString *s = [NSString stringWithFormat:NSLocalizedString(@"Mark - %@", @""),
				   [NSDateFormatter localizedStringFromDate:[NSDate date]
												  dateStyle:NSDateFormatterShortStyle
												  timeStyle:NSDateFormatterMediumStyle]];
	[markTitleField setStringValue:s];
	
	[NSApp beginSheet:markTitleWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addMarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[aMessage retain]];
}

- (IBAction)addMark:(id)sender
{
	[self addMarkWithTitleString:nil beforeMessage:nil];
}

- (IBAction)addMarkWithTitle:(id)sender
{
	[self addMarkWithTitleBeforeMessage:nil];
}

- (IBAction)insertMarkWithTitle:(id)sender
{
	NSInteger rowIndex = [logTable selectedRow];
	if (rowIndex >= 0 && rowIndex < (NSInteger)[displayedMessages count])
		[self addMarkWithTitleBeforeMessage:[displayedMessages objectAtIndex:(NSUInteger)rowIndex]];
}

- (IBAction)deleteMark:(id)sender
{
	NSInteger rowIndex = [logTable selectedRow];
	if (rowIndex >= 0 && rowIndex < (NSInteger)[displayedMessages count])
	{
		LoggerMessage *markMessage = [displayedMessages objectAtIndex:(NSUInteger)rowIndex];
		assert(markMessage.type == LOGMSG_TYPE_MARK);
		[displayedMessages removeObjectAtIndex:(NSUInteger)rowIndex];
		[logTable reloadData];
		[self rebuildMarksSubmenu];
		dispatch_async(messageFilteringQueue, ^{
			// then we serialize all operations modifying the messages list in the connection's
			// message processing queue
			dispatch_async(attachedConnection.messageProcessingQueue, ^{
				@synchronized(attachedConnection.messages) {
					[attachedConnection.messages removeObjectIdenticalTo:markMessage];
				}
				dispatch_async(dispatch_get_main_queue(), ^{
					[[self document] updateChangeCount:NSChangeDone];
				});
			});
		});
	}
}

- (IBAction)cancelAddMark:(id)sender
{
	[NSApp endSheet:markTitleWindow returnCode:0];
}

- (IBAction)validateAddMark:(id)sender
{
	[NSApp endSheet:markTitleWindow returnCode:1];
}

- (void)addMarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode)
		[self addMarkWithTitleString:[markTitleField stringValue] beforeMessage:(LoggerMessage *)contextInfo];
	if (contextInfo != NULL)
		[(id)contextInfo release];
	[markTitleWindow orderOut:self];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark User Interface Items Validation
// -----------------------------------------------------------------------------
- (BOOL)validateUserInterfaceItem:(id)anItem
{
	SEL action = [anItem action];
	if (action == @selector(deleteMark:))
	{
		NSInteger rowIndex = [logTable selectedRow];
		if (rowIndex >= 0 && rowIndex < (NSInteger)[displayedMessages count])
		{
			LoggerMessage *markMessage = [displayedMessages objectAtIndex:(NSUInteger)rowIndex];
			return (markMessage.type == LOGMSG_TYPE_MARK);
		}
		return NO;
	}
	else if (action == @selector(clearCurrentLog:))
	{
		// Allow "Clear Log" only if the log was not restored from save
		if (attachedConnection == nil || attachedConnection.restoredFromSave)
			return NO;
	}
	else if (action == @selector(clearAllLogs:))
	{
		// Allow "Clear All Run Logs" only if the log was not restored from save
		// and there are multiple run logs
		if (attachedConnection == nil || attachedConnection.restoredFromSave || [((LoggerDocument *)[self document]).attachedLogs count] <= 1)
			return NO;
	}
	else if (action == @selector(copy:))
	{
		return logTable.selectedRowIndexes.count > 0;
	}
	return YES;
}

#pragma mark -
#pragma mark - Clipboard actions

- (void)copy:(id)sender
{
	NSArray *selectedMessages = [displayedMessages objectsAtIndexes:logTable.selectedRowIndexes];
	if (selectedMessages.count == 0)
		return;
	
	NSArray *messages = [selectedMessages valueForKeyPath:NSStringFromSelector(@selector(message))];
	NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
	[generalPasteboard declareTypes:@[ NSPasteboardTypeString ] owner:nil];
	[generalPasteboard setString:[messages componentsJoinedByString:@"\n"] forType:NSPasteboardTypeString];
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Support for clear current // all logs
// -----------------------------------------------------------------------------
- (BOOL)canClearCurrentLog
{
	return (attachedConnection != nil && !attachedConnection.restoredFromSave);
}

- (IBAction)clearCurrentLog:(id)sender
{
	[(LoggerDocument *)[self document] clearLogs:NO];
}

- (BOOL)canClearAllLogs
{
	return (attachedConnection != nil && !attachedConnection.restoredFromSave && [((LoggerDocument *)[self document]).attachedLogs count] > 1);
}

- (IBAction)clearAllLogs:(id)sender
{
	[(LoggerDocument *)[self document] clearLogs:YES];
}

#pragma mark - 
#pragma mark - Collapsing Taskbar

- (IBAction)collapseTaskbar:(id)sender{
    
    NSMenuItem *hideShowButton = [[[[NSApp mainMenu] itemWithTag:VIEW_MENU_ITEM_TAG] submenu] itemWithTag:TOOLS_MENU_HIDE_SHOW_TOOLBAR];
    
    if (![splitView collapsibleSubviewCollapsed]) {
        [hideShowButton setTitle:NSLocalizedString(@"Show Taskbar", @"Show Taskbar")];
    }
    else{
        [hideShowButton setTitle:NSLocalizedString(@"Hide Taskbar", @"Hide Taskbar")];
    }

    [splitView toggleCollapse:nil];

}

@end

