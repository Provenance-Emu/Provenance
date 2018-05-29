/*
 * LoggerPrefsWindowController.m
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
#include <sys/time.h>
#import "LoggerPrefsWindowController.h"
#import "LoggerAppDelegate.h"
#import "LoggerMessage.h"
#import "LoggerMessageCell.h"
#import "LoggerConnection.h"

enum {
	kTimestampFont = 1,
	kThreadIDFont,
	kTagAndLevelFont,
	kTextFont,
	kDataFont,
	kFileFunctionFont
};

enum {
	kTimestampFontColor = 1,
	kThreadIDFontColor,
	kTagAndLevelFontColor,
	kTextFontColor,
	kDataFontColor,
	kFileFunctionFontColor,
	kFileFunctionBackgroundColor
};

NSString * const kPrefsChangedNotification = @"PrefsChangedNotification";
void *advancedColorsArrayControllerDidChange = &advancedColorsArrayControllerDidChange;

@implementation SampleMessageControl
- (BOOL)isFlipped
{
	return YES;
}
@end

@interface LoggerPrefsWindowController (Private)
- (void)updateUI;
- (NSMutableDictionary *)copyNetworkPrefs;
@end

@implementation LoggerPrefsWindowController

@synthesize advancedColors = _advancedColors;
@synthesize advancedColorsArrayController;
@synthesize advancedColorsTableView;

- (id)initWithWindowNibName:(NSString *)windowNibName
{
	if ((self = [super initWithWindowNibName:windowNibName]) != nil)
	{
		// Extract current prefs for bindings. We don't want to rely on a global NSUserDefaultsController
		networkPrefs = [self copyNetworkPrefs];

		// make a deep copy of default attributes by going back and forth with
		// an archiver
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[LoggerMessageCell defaultAttributes]];
		attributes = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
        _advancedColors = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"advancedColors"]];
	}
	return self;
}

- (void)dealloc
{
	[fakeConnection release];
	[attributes release];
	[networkPrefs release];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSControlTextDidEndEditingNotification object:nil];
	[super dealloc];
}

- (NSMutableDictionary *)copyNetworkPrefs
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	return [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			[ud objectForKey:kPrefPublishesBonjourService], kPrefPublishesBonjourService,
			[ud objectForKey:kPrefBonjourServiceName], kPrefBonjourServiceName,
			[ud objectForKey:kPrefHasDirectTCPIPResponder], kPrefHasDirectTCPIPResponder,
			[ud objectForKey:kPrefDirectTCPIPResponderPort], kPrefDirectTCPIPResponderPort,
			nil];
}

- (void)awakeFromNib
{
	// Prepare a couple fake messages to get a sample display
	struct timeval tv;
	gettimeofday(&tv, NULL);

	LoggerMessage *prevMsg = [[LoggerMessage alloc] init];
	if (tv.tv_usec)
		tv.tv_usec = 0;
	else
	{
		tv.tv_sec--;
		tv.tv_usec = 500000;
	}
	prevMsg.timestamp = tv;

	fakeConnection = [[LoggerConnection alloc] init];

	LoggerMessage *msg = [[LoggerMessage alloc] init];
	msg.timestamp = tv;
	msg.tag = @"database";
	msg.message = @"Example message text";
	msg.threadID = @"Main thread";
	msg.level = 0;
	msg.contentsType = kMessageString;
	msg.cachedCellSize = sampleMessage.frame.size;
	[msg setFilename:@"file.m" connection:fakeConnection];
	msg.lineNumber = 100;
	[msg setFunctionName:@"-[MyClass aMethod:withParameters:]" connection:fakeConnection];

	LoggerMessageCell *cell = [[LoggerMessageCell alloc] init];
	cell.message = msg;
	cell.previousMessage = prevMsg;
	cell.shouldShowFunctionNames = YES;
	[sampleMessage setCell:cell];
	[cell release];
	[msg release];

	uint8_t bytes[32];
	for (int i = 0; i < sizeof(bytes); i++)
		bytes[i] = (uint8_t)arc4random();

	cell = [[LoggerMessageCell alloc] init];
	msg = [[LoggerMessage alloc] init];
	msg.timestamp = tv;
	msg.tag = @"network";
	msg.message = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	msg.threadID = @"Main thread";
	msg.level = 1;
	msg.contentsType = kMessageData;
	msg.cachedCellSize = sampleDataMessage.frame.size;
	cell.message = msg;
	cell.previousMessage = prevMsg;
	[sampleDataMessage setCell:cell];
	[cell release];
	[msg release];
	[prevMsg release];

	[self updateUI];
	[sampleMessage setNeedsDisplay];
	[sampleDataMessage setNeedsDisplay];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editingDidEnd:) name:NSControlTextDidEndEditingNotification object:nil];
}

- (BOOL)hasNetworkChanges
{
	// Check whether attributes or network settings have changed
	for (NSString *key in networkPrefs)
	{
		if (![[[NSUserDefaults standardUserDefaults] objectForKey:key] isEqual:[networkPrefs objectForKey:key]])
			return YES;
	}
	return NO;
}

- (BOOL)hasFontChanges
{
	return (NO == [[LoggerMessageCell defaultAttributes] isEqual:attributes]);
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Close & Apply management
// -----------------------------------------------------------------------------
- (BOOL)windowShouldClose:(id)sender
{
	if (![networkDefaultsController commitEditing])
		return NO;
	if ([self hasNetworkChanges] || [self hasFontChanges])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString(@"Would you like to apply your changes before closing the Preferences window?", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Apply", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Don't Apply", @"")];
		[alert beginSheetModalForWindow:[self window]
						  modalDelegate:self
						 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
							contextInfo:NULL];
		[alert release];
		return NO;
	}
	return YES;
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:self];
	if (returnCode == NSAlertFirstButtonReturn)
	{
		// Apply (and close window)
		if ([self hasNetworkChanges])
			[self applyNetworkChanges:nil];
		if ([self hasFontChanges])
			[self applyFontChanges:nil];
		[[self window] performSelector:@selector(close) withObject:nil afterDelay:0];
	}
	else if (returnCode == NSAlertSecondButtonReturn)
	{
		// Cancel (don't close window)
		// nothing more to do
	}
	else
	{
		// Don't Apply (and close window)
		[[self window] performSelector:@selector(close) withObject:nil afterDelay:0];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Network preferences
// -----------------------------------------------------------------------------
- (IBAction)restoreNetworkDefaults:(id)sender
{
	[networkDefaultsController commitEditing];
	NSDictionary *dict = [LoggerAppDelegate defaultPreferences];
	for (NSString *key in dict)
	{
		if ([networkPrefs objectForKey:key] != nil)
			[[networkDefaultsController selection] setValue:[dict objectForKey:key] forKey:key];
	}
}

- (void)applyNetworkChanges:(id)sender
{
	if ([networkDefaultsController commitEditing])
	{
		NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
		for (NSString *key in [networkPrefs allKeys])
			[ud setObject:[networkPrefs objectForKey:key] forKey:key];
		[ud synchronize];
		[[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:self];
	}
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark Font preferences
// -----------------------------------------------------------------------------
- (IBAction)applyFontChanges:(id)sender
{
	[[LoggerMessageCell class] setDefaultAttributes:attributes];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:self];
}

- (IBAction)restoreFontDefaults:(id)sender
{
	[attributes release];
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[LoggerMessageCell defaultAttributesDictionary]];
	attributes = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	((LoggerMessageCell *)[sampleMessage cell]).messageAttributes = attributes;
	((LoggerMessageCell *)[sampleDataMessage cell]).messageAttributes = attributes;
	[sampleMessage setNeedsDisplay];
	[sampleDataMessage setNeedsDisplay];
	[self updateUI];
}

- (NSMutableDictionary *)_blankAdvancedColor {
    return [[[NSMutableDictionary alloc] initWithObjects:@[@"Any line", @"^.+$", @"black"] forKeys:@[@"comment", @"regexp", @"colors"]] autorelease];
}

- (IBAction)advancedColorsAdd:(id)sender {
    [self.advancedColors addObject:[self _blankAdvancedColor]];
    [self.advancedColorsArrayController rearrangeObjects];
    [self commitAdvancedColorsChanges];
}

- (IBAction)advancedColorsDel:(id)sender {
    NSArray *selection = [self.advancedColorsArrayController selectedObjects];
    [self.advancedColors removeObjectsInArray:selection];
	if (self.advancedColors.count == 0) {
		[self.advancedColors addObject:[self _blankAdvancedColor]];
	}
    [self.advancedColorsArrayController rearrangeObjects];
    [self commitAdvancedColorsChanges];
}

- (NSFont *)fontForCurrentFontSelection
{
	NSFont *font;
	switch (currentFontSelection)
	{
		case kTimestampFont:
			font = [[attributes objectForKey:@"timestamp"] objectForKey:NSFontAttributeName];
			break;
		case kThreadIDFont:
			font = [[attributes objectForKey:@"threadID"] objectForKey:NSFontAttributeName];
			break;
		case kTagAndLevelFont:
			font = [[attributes objectForKey:@"tag"] objectForKey:NSFontAttributeName];
			break;
		case kDataFont:
			font = [[attributes objectForKey:@"data"] objectForKey:NSFontAttributeName];
			break;
		case kFileFunctionFont:
			font = [[attributes objectForKey:@"fileLineFunction"] objectForKey:NSFontAttributeName];
			break;
		default:
			font = [[attributes objectForKey:@"text"] objectForKey:NSFontAttributeName];
			break;
	}
	return font;	
}

- (IBAction)selectFont:(id)sender
{
	currentFontSelection = [(NSView *)sender tag];
	[[NSFontManager sharedFontManager] setTarget:self];
	[[NSFontPanel sharedFontPanel] setPanelFont:[self fontForCurrentFontSelection] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

- (IBAction)selectColor:(id)sender
{
	NSString *attrName = NSForegroundColorAttributeName, *dictName = nil, *dictName2 = nil;
	int tag = [(NSView *)sender tag];
	if (tag == kTimestampFontColor)
		dictName = @"timestamp";
	else if (tag == kThreadIDFontColor)
		dictName = @"threadID";
	else if (tag == kTagAndLevelFontColor)
	{
		dictName = @"tag";
		dictName2 = @"level";
	}
	else if (tag == kTextFontColor)
		dictName = @"text";
	else if (tag == kDataFontColor)
		dictName = @"data";
	else if (tag == kFileFunctionFontColor)
		dictName = @"fileLineFunction";
	else if (tag == kFileFunctionBackgroundColor)
	{
		dictName = @"fileLineFunction";
		attrName = NSBackgroundColorAttributeName;
	}
	if (dictName != nil)
	{
		[[attributes objectForKey:dictName] setObject:[sender color] forKey:attrName];
		if (dictName2 != nil)
			[[attributes objectForKey:dictName2] setObject:[sender color] forKey:attrName];
		((LoggerMessageCell *)[sampleMessage cell]).messageAttributes = attributes;
		((LoggerMessageCell *)[sampleDataMessage cell]).messageAttributes = attributes;
		[sampleMessage setNeedsDisplay];
		[sampleDataMessage setNeedsDisplay];
	}
}

- (void)changeFont:(id)sender
{
    NSFont *newFont = [sender convertFont:[self fontForCurrentFontSelection]];
	switch (currentFontSelection)
	{
		case kTimestampFont:
			[[attributes objectForKey:@"timestamp"] setObject:newFont forKey:NSFontAttributeName];
			[[attributes objectForKey:@"timedelta"] setObject:newFont forKey:NSFontAttributeName];
			break;
		case kThreadIDFont:
			[[attributes objectForKey:@"threadID"] setObject:newFont forKey:NSFontAttributeName];
			break;
		case kTagAndLevelFont:
			[[attributes objectForKey:@"tag"] setObject:newFont forKey:NSFontAttributeName];
			[[attributes objectForKey:@"level"] setObject:newFont forKey:NSFontAttributeName];
			break;
		case kDataFont:
			[[attributes objectForKey:@"data"] setObject:newFont forKey:NSFontAttributeName];
			break;
		case kFileFunctionFont:
			[[attributes objectForKey:@"fileLineFunction"] setObject:newFont forKey:NSFontAttributeName];
			break;
		default: {
			[[attributes objectForKey:@"text"] setObject:newFont forKey:NSFontAttributeName];
			[[attributes objectForKey:@"mark"] setObject:newFont forKey:NSFontAttributeName];
			break;
		}
	}
	((LoggerMessageCell *)[sampleMessage cell]).messageAttributes = attributes;
	((LoggerMessageCell *)[sampleDataMessage cell]).messageAttributes = attributes;
	[sampleMessage setNeedsDisplay];
	[sampleDataMessage setNeedsDisplay];
	[self updateUI];
}

- (NSString *)fontNameForFont:(NSFont *)aFont
{
	return [NSString stringWithFormat:@"%@ %.1f", [aFont displayName], [aFont pointSize]];
}

- (void)updateColor:(NSColorWell *)well ofDict:(NSString *)dictName attribute:(NSString *)attrName
{
	NSColor *color = [[attributes objectForKey:dictName] objectForKey:attrName];
	if (color == nil)
	{
		if ([attrName isEqualToString:NSForegroundColorAttributeName])
			color = [NSColor blackColor];
		else
			color = [NSColor clearColor];
	}
	[well setColor:color];
}

- (void)updateUI
{
	[timestampFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"timestamp"] objectForKey:NSFontAttributeName]]];
	[threadIDFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"threadID"] objectForKey:NSFontAttributeName]]];
	[tagFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"tag"] objectForKey:NSFontAttributeName]]];
	[textFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"text"] objectForKey:NSFontAttributeName]]];
	[dataFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"data"] objectForKey:NSFontAttributeName]]];
	[fileFunctionFontName setStringValue:[self fontNameForFont:[[attributes objectForKey:@"fileLineFunction"] objectForKey:NSFontAttributeName]]];

	[self updateColor:timestampForegroundColor ofDict:@"timestamp" attribute:NSForegroundColorAttributeName];
	[self updateColor:threadIDForegroundColor ofDict:@"threadID" attribute:NSForegroundColorAttributeName];
	[self updateColor:tagLevelForegroundColor ofDict:@"tag" attribute:NSForegroundColorAttributeName];
	[self updateColor:textForegroundColor ofDict:@"text" attribute:NSForegroundColorAttributeName];
	[self updateColor:dataForegroundColor ofDict:@"data" attribute:NSForegroundColorAttributeName];
	[self updateColor:fileFunctionForegroundColor ofDict:@"fileLineFunction" attribute:NSForegroundColorAttributeName];
	[self updateColor:fileFunctionBackgroundColor ofDict:@"fileLineFunction" attribute:NSBackgroundColorAttributeName];
}

- (void)commitAdvancedColorsChanges
{
    if ([self.advancedColorsArrayController commitEditing]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud setObject:self.advancedColors forKey:@"advancedColors"];
        [ud synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:self];
    }
}

- (void)editingDidEnd:(NSNotification *)notification
{
    [self commitAdvancedColorsChanges];
}

@end
