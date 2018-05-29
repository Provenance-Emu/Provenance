/*
 * LoggerWindowController.h
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
#import "LoggerConnection.h"
#import "BWToolkitFramework.h"

@class LoggerMessageCell, LoggerClientInfoCell, LoggerMarkerCell, LoggerTableView, LoggerSplitView;
@class LoggerDetailsWindowController;

@interface LoggerWindowController : NSWindowController <NSWindowDelegate, LoggerConnectionDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate>
{
	IBOutlet LoggerTableView *logTable;
	IBOutlet NSTableView *filterSetsTable;
	IBOutlet NSTableView *filterTable;
	IBOutlet NSPopUpButton *quickFilter;
	IBOutlet NSButton *showFunctionNamesButton;
	IBOutlet NSSearchField *quickFilterTextField;
	IBOutlet BWAnchoredButtonBar *buttonBar;

	IBOutlet NSArrayController *filterSetsListController;
	IBOutlet NSArrayController *filterListController;

	IBOutlet NSWindow *filterEditorWindow;
	IBOutlet NSPredicateEditor *filterEditor;
	IBOutlet NSTextField *filterName;
	
	IBOutlet NSWindow *markTitleWindow;
	IBOutlet NSTextField *markTitleField;
    IBOutlet LoggerSplitView *splitView;

	LoggerConnection *attachedConnection;
	LoggerDetailsWindowController *detailsWindowController;

	LoggerMessageCell *messageCell;
	LoggerClientInfoCell *clientInfoCell;
	LoggerMarkerCell *markerCell;
    CGFloat threadColumnWidth;

	NSString *info;
	NSMutableArray *displayedMessages;
	NSMutableSet *tags;

	NSPredicate *filterPredicate;				// created from current selected filters, + quick filter string / tag / log level

	NSString *filterString;
	NSMutableSet *filterTags;
	int logLevel;

	dispatch_queue_t messageFilteringQueue;
	dispatch_group_t lastTilingGroup;

	int lastMessageRow;
	BOOL messagesSelected;
	BOOL hasQuickFilter;
	BOOL initialRefreshDone;
	BOOL showFunctionNames;
	BOOL clientAppSettingsRestored;
}

@property (nonatomic, retain) LoggerConnection *attachedConnection;
@property (nonatomic, assign) BOOL messagesSelected;
@property (nonatomic, assign) BOOL hasQuickFilter;
@property (nonatomic, assign) NSNumber* showFunctionNames;
@property (nonatomic, assign) CGFloat threadColumnWidth;

- (IBAction)openDetailsWindow:(id)sender;

- (IBAction)selectQuickFilterTag:(id)sender;
- (IBAction)selectQuickFilterLevel:(id)sender;
- (IBAction)resetQuickFilter:(id)sender;

- (IBAction)addFilterSet:(id)sender;
- (IBAction)deleteSelectedFilterSet:(id)sender;

- (IBAction)addFilter:(id)sender;
- (IBAction)startEditingFilter:(id)sender;
- (IBAction)cancelFilterEdition:(id)sender;
- (IBAction)validateFilterEdition:(id)sender;
- (IBAction)deleteSelectedFilters:(id)sender;
- (IBAction)createNewFilterFromQuickFilter:(id) sender;

- (IBAction)addMark:(id)sender;
- (IBAction)addMarkWithTitle:(id)sender;
- (IBAction)insertMarkWithTitle:(id)sender;
- (IBAction)cancelAddMark:(id)sender;
- (IBAction)validateAddMark:(id)sender;
- (IBAction)deleteMark:(id)sender;

- (IBAction)clearCurrentLog:(id)sender;
- (IBAction)clearAllLogs:(id)sender;

- (IBAction)collapseTaskbar:(id)sender;

- (void)updateMenuBar:(BOOL)documentIsFront;

@end

@interface LoggerTableView : NSTableView
{
}
@end

#define	DEFAULT_THREAD_COLUMN_WIDTH	85.0f


