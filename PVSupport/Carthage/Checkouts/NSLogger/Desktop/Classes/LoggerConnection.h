/*
 * LoggerConnection.h
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

@class LoggerConnection, LoggerMessage;

// -----------------------------------------------------------------------------
// LoggerConnectionDelegate protocol
// -----------------------------------------------------------------------------
@protocol LoggerConnectionDelegate
// method that may not be called on main thread
- (void)connection:(LoggerConnection *)theConnection didReceiveMessages:(NSArray *)theMessages range:(NSRange)rangeInMessagesList;
@end

@interface NSObject (LoggerConnectionDelegateOptional)
// method always called on main thread
- (void)remoteDisconnected:(LoggerConnection *)theConnection;
@end

// -----------------------------------------------------------------------------
// NSLoggerConnection class
// -----------------------------------------------------------------------------
@interface LoggerConnection : NSObject <NSCoding>
{
	id<LoggerConnectionDelegate> delegate;

	// Client info, as transmitted
	NSString *clientName;
	NSString *clientVersion;
	NSString *clientOSName;
	NSString *clientOSVersion;
	NSString *clientDevice;
	NSString *clientUDID;

	NSMutableSet *filenames;			// pool of unique file names
	NSMutableSet *functionNames;		// pool of unique function names

	NSData *clientAddress;				// depends on the underlying protocol

	NSMutableArray *messages;
	NSMutableArray *parentIndexesStack;	// during messages receive, use this to quickly locate parent indexes in groups
	dispatch_queue_t messageProcessingQueue;

	int reconnectionCount;				// when a reconnection is detected (same client, disconnects then reconnects), the # reconnection for this connection
	BOOL connected;
	BOOL restoredFromSave;
	BOOL attachedToWindow;
}

@property (retain) id <LoggerConnectionDelegate> delegate;

@property (nonatomic, retain) NSString *clientName;
@property (nonatomic, retain) NSString *clientVersion;
@property (nonatomic, retain) NSString *clientOSName;
@property (nonatomic, retain) NSString *clientOSVersion;
@property (nonatomic, retain) NSString *clientDevice;
@property (nonatomic, retain) NSString *clientUDID;

@property (nonatomic, readonly) NSData *clientAddress;
@property (nonatomic, readonly) NSMutableSet *filenames;
@property (nonatomic, readonly) NSMutableSet *functionNames;

@property (nonatomic, readonly) NSMutableArray *messages;
@property (nonatomic, assign) int reconnectionCount;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, readonly) BOOL restoredFromSave;
@property (nonatomic, assign) BOOL attachedToWindow;
@property (nonatomic, readonly) dispatch_queue_t messageProcessingQueue;

- (id)initWithAddress:(NSData *)anAddress;
- (void)shutdown;

- (void)messagesReceived:(NSArray *)msgs;
- (void)clientInfoReceived:(LoggerMessage *)message;
- (void)clearMessages;

- (NSString *)clientAppDescription;
- (NSString *)clientAddressDescription;
- (NSString *)clientDescription;

- (BOOL)isNewRunOfClient:(LoggerConnection *)aConnection;

@end

extern char sConnectionAssociatedObjectKey;
