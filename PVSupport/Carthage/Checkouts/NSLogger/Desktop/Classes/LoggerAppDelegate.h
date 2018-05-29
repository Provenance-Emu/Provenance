/*
 * LoggerAppDelegate.h
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
#import <Cocoa/Cocoa.h>

@class LoggerConnection, LoggerTransport, LoggerStatusWindowController, LoggerPrefsWindowController;

@interface LoggerAppDelegate : NSObject
{
	CFArrayRef serverCerts;
	BOOL serverCertsLoadAttempted;
	NSMutableArray *transports;
	NSMutableArray *filterSets;
	NSArray *filtersSortDescriptors;
	LoggerStatusWindowController *statusController;
	LoggerPrefsWindowController *prefsController;
}

@property (nonatomic, readonly) CFArrayRef serverCerts;
@property (nonatomic, readonly) BOOL serverCertsLoadAttempted;
@property (nonatomic, readonly) NSMutableArray *transports;
@property (nonatomic, readonly) NSMutableArray *filterSets;
@property (nonatomic, retain) NSArray *filtersSortDescriptors;
@property (nonatomic, readonly) LoggerStatusWindowController *statusController;

+ (NSDictionary *)defaultPreferences;

- (void)newConnection:(LoggerConnection *)aConnection fromTransport:(LoggerTransport *)aTransport;

- (NSMutableArray *)defaultFilters;
- (NSNumber *)nextUniqueFilterIdentifier:(NSArray *)filters;
- (void)saveFiltersDefinition;

- (IBAction)showPreferences:(id)sender;

- (BOOL)loadEncryptionCertificate:(NSError **)outError;

@end

extern NSString * const kPrefKeepMultipleRuns;
extern NSString * const kPrefCloseWithoutSaving;

extern NSString * const kPrefPublishesBonjourService;
extern NSString * const kPrefHasDirectTCPIPResponder;
extern NSString * const kPrefDirectTCPIPResponderPort;
extern NSString * const kPrefBonjourServiceName;
extern NSString * const kPrefClientApplicationSettings;

extern NSString * const kPref_ApplicationFilterSet;

// Menu item identifiers
#define TOOLS_MENU_ITEM_TAG				        1
#define TOOLS_MENU_ADD_MARK_TAG					1
#define TOOLS_MENU_ADD_MARK_WITH_TITLE_TAG		2
#define TOOLS_MENU_INSERT_MARK_TAG				3
#define TOOLS_MENU_DELETE_MARK_TAG				4
#define TOOLS_MENU_JUMP_TO_MARK_TAG				5
#define TOOLS_MENU_HIDE_SHOW_TOOLBAR		    7

#define VIEW_MENU_ITEM_TAG                      2
#define VIEW_MENU_SWITCH_TO_RUN_TAG				6
