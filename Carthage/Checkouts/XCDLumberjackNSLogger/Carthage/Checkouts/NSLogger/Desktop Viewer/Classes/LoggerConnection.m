/*
 * LoggerConnection.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
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
#include <netinet/in.h>
#import <objc/runtime.h>
#import "LoggerConnection.h"
#import "LoggerMessage.h"
#import "LoggerCommon.h"
#import "LoggerAppDelegate.h"
#import "LoggerStatusWindowController.h"

char sConnectionAssociatedObjectKey = 1;

@implementation LoggerConnection

@synthesize delegate;
@synthesize messages;
@synthesize reconnectionCount, connected, restoredFromSave, attachedToWindow;
@synthesize clientName, clientVersion, clientOSName, clientOSVersion, clientDevice, clientAddress, clientUDID;
@synthesize messageProcessingQueue;
@synthesize filenames, functionNames;

- (id)init
{
	if ((self = [super init]) != nil)
	{
		messageProcessingQueue = dispatch_queue_create("com.florentpillet.nslogger.messageProcessingQueue", NULL);
		messages = [[NSMutableArray alloc] initWithCapacity:1024];
		parentIndexesStack = [[NSMutableArray alloc] init];
		filenames = [[NSMutableSet alloc] init];
		functionNames = [[NSMutableSet alloc] init];
	}
	return self;
}

- (id)initWithAddress:(NSData *)anAddress
{
	if ((self = [super init]) != nil)
	{
		messageProcessingQueue = dispatch_queue_create("com.florentpillet.nslogger.messageProcessingQueue", NULL);
		messages = [[NSMutableArray alloc] initWithCapacity:1024];
		parentIndexesStack = [[NSMutableArray alloc] init];
		clientAddress = [anAddress copy];
		filenames = [[NSMutableSet alloc] init];
		functionNames = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void)dealloc
{
	dispatch_release(messageProcessingQueue);
	[messages release];
	[parentIndexesStack release];
	[clientName release];
	[clientVersion release];
	[clientOSName release];
	[clientOSVersion release];
	[clientDevice release];
	[clientAddress release];
	[clientUDID release];
	[filenames release];
	[functionNames release];
	[super dealloc];
}

- (BOOL)isNewRunOfClient:(LoggerConnection *)aConnection
{
	// Try to detect if a connection is a new run of an older, disconnected session
	// (goal is to detect restarts, so as to replace logs in the same window)
	assert(restoredFromSave == NO);

	// exclude files loaded from disk
	if (aConnection.restoredFromSave)
		return NO;
	
	// as well as still-up connections
	if (aConnection.connected)
		return NO;

	// check whether client info is the same
	BOOL (^isSame)(NSString *, NSString *) = ^(NSString *s1, NSString *s2)
	{
		if ((s1 == nil) != (s2 == nil))
			return NO;
		if (s1 != nil && ![s2 isEqualToString:s1])
			return NO;
		return YES;	// s1 and d2 either nil or same
	};

	if (!isSame(clientName, aConnection.clientName) ||
		!isSame(clientVersion, aConnection.clientVersion) ||
		!isSame(clientOSName, aConnection.clientOSName) ||
		!isSame(clientOSVersion, aConnection.clientOSVersion) ||
		!isSame(clientDevice, aConnection.clientDevice))
	{
		return NO;
	}
	
	// check whether address is the same, OR hardware ID (if present) is the same.
	// hardware ID wins (on desktop, iOS simulator can connect have different
	// addresses from run to run if the computer has multiple network interfaces / VMs installed
	if (clientUDID != nil && isSame(clientUDID, aConnection.clientUDID))
		return YES;
	
	if ((clientAddress != nil) != (aConnection.clientAddress != nil))
		return NO;

	if (clientAddress != nil)
	{
		// compare address blocks sizes (ipv4 vs. ipv6)
		NSUInteger addrSize = [clientAddress length];
		if (addrSize != [aConnection.clientAddress length])
			return NO;
		
		// compare ipv4 or ipv6 address. We don't want to compare the source port,
		// because it will change with each connection
		if (addrSize == sizeof(struct sockaddr_in))
		{
			struct sockaddr_in addra, addrb;
			[clientAddress getBytes:&addra];
			[aConnection.clientAddress getBytes:&addrb];
			if (memcmp(&addra.sin_addr, &addrb.sin_addr, sizeof(addra.sin_addr)))
				return NO;
		}
		else if (addrSize == sizeof(struct sockaddr_in6))
		{
			struct sockaddr_in6 addr6a, addr6b;
			[clientAddress getBytes:&addr6a];
			[aConnection.clientAddress getBytes:&addr6b];
			if (memcmp(&addr6a.sin6_addr, &addr6b.sin6_addr, sizeof(addr6a.sin6_addr)))
				return NO;
		}
		else if (![clientAddress isEqualToData:aConnection.clientAddress])
			return NO;		// we only support ipv4 and ipv6, so this should not happen
	}
	
	return YES;
}

- (void)messagesReceived:(NSArray *)msgs
{
	dispatch_async(messageProcessingQueue, ^{
		/* Code not functional yet
		 *
		NSRange range = NSMakeRange([messages count], [msgs count]);
		NSUInteger lastParent = NSNotFound;
		if ([parentIndexesStack count])
			lastParent = [[parentIndexesStack lastObject] intValue];
		
		for (NSUInteger i = 0, count = [msgs count]; i < count; i++)
		{
			// update cache for indentation
			LoggerMessage *message = [msgs objectAtIndex:i];
			switch (message.type)
			{
				case LOGMSG_TYPE_BLOCKSTART:
					[parentIndexesStack addObject:[NSNumber numberWithInt:range.location+i]];
					lastParent = range.location + i;
					break;
					
				case LOGMSG_TYPE_BLOCKEND:
					if ([parentIndexesStack count])
					{
						[parentIndexesStack removeLastObject];
						if ([parentIndexesStack count])
							lastParent = [[parentIndexesStack lastObject] intValue];
						else
							lastParent = NSNotFound;
					}
					break;
					
				default:
					if (lastParent != NSNotFound)
					{
						message.distanceFromParent = range.location + i - lastParent;
						message.indent = [parentIndexesStack count];
					}
					break;
			}
		}
		 *
		 */
		NSRange range;
		@synchronized (messages)
		{
			range = NSMakeRange([messages count], [msgs count]);
			[messages addObjectsFromArray:msgs];
		}
		
		if (attachedToWindow)
			[self.delegate connection:self didReceiveMessages:msgs range:range];
	});
}

- (void)clearMessages
{
	// Clear the backlog of messages, only keeping the top (client info) message
	// This MUST be called on the messageProcessingQueue
	assert(dispatch_get_current_queue() == messageProcessingQueue);
	if (![messages count])
		return;

	// Locate the clientInfo message
	if (((LoggerMessage *)[messages objectAtIndex:0]).type == LOGMSG_TYPE_CLIENTINFO)
		[messages removeObjectsInRange:NSMakeRange(1, [messages count]-1)];
	else
		[messages removeAllObjects];
}

- (void)clientInfoReceived:(LoggerMessage *)message
{
	// Insert message at first position in the message list. In the unlikely event there is
	// an existing ClientInfo message at this position, just replace it. Also, don't fire
	// a "didReceiveMessages". The rationale behind this is that if the connection just came in,
	// we are not yet attached to a window and when attaching, the window will refresh all messages.
	dispatch_async(messageProcessingQueue, ^{
		@synchronized (messages)
		{
			if ([messages count] == 0 || ((LoggerMessage *)[messages objectAtIndex:0]).type != LOGMSG_TYPE_CLIENTINFO)
				[messages insertObject:message atIndex:0];
		}
	});

	// all this stuff occurs on the main thread to avoid touching values
	// while the UI reads them
	dispatch_async(dispatch_get_main_queue(), ^{
		NSDictionary *parts = message.parts;
		id value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_NAME]];
		if (value != nil)
			self.clientName = value;
		value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_VERSION]];
		if (value != nil)
			self.clientVersion = value;
		value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_OS_NAME]];
		if (value != nil)
			self.clientOSName = value;
		value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_OS_VERSION]];
		if (value != nil)
			self.clientOSVersion = value;
		value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_MODEL]];
		if (value != nil)
			self.clientDevice = value;
		value = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_UNIQUEID]];
		if (value != nil)
			self.clientUDID = value;

		[[NSNotificationCenter defaultCenter] postNotificationName:kShowStatusInStatusWindowNotification
															object:self];
	});
}

- (NSString *)clientAppDescription
{
	// enforce thread safety (only on main thread)
	assert([NSThread isMainThread]);
	NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
	if (clientName != nil)
		[s appendString:clientName];
	if (clientVersion != nil)
		[s appendFormat:@" %@", clientVersion];
	if (clientName == nil && clientVersion == nil)
		[s appendString:NSLocalizedString(@"<unknown>", @"")];
	if (clientOSName != nil && clientOSVersion != nil)
		[s appendFormat:@"%@(%@ %@)", [s length] ? @" " : @"", clientOSName, clientOSVersion];
	else if (clientOSName != nil)
		[s appendFormat:@"%@(%@)", [s length] ? @" " : @"", clientOSName];

	return s;
}

- (NSString *)clientAddressDescription
{
	// subclasses should implement this
	return @"";
}

- (NSString *)clientDescription
{
	// enforce thread safety (only on main thread)
	assert([NSThread isMainThread]);
	NSString *clientAppDescription = [self clientAppDescription];
	NSString *clientAddressDescription = [self clientAddressDescription];
	return clientAddressDescription ? [NSString stringWithFormat:@"%@ @ %@", clientAppDescription, clientAddressDescription] : clientAppDescription;
}

- (NSString *)status
{
	// status is being observed by LoggerStatusWindowController and changes once
	// when the connection gets disconnected
	NSString *format;
	if (connected)
		format = NSLocalizedString(@"%@ connected", @"");
	else
		format = NSLocalizedString(@"%@ disconnected", @"");
	if ([NSThread isMainThread])
		return [NSString stringWithFormat:format, [self clientDescription]];
	__block NSString *status;
	dispatch_sync(dispatch_get_main_queue(), ^{
		status = [[NSString stringWithFormat:format, [self clientDescription]] retain];
	});
	return [status autorelease];
}

- (void)setConnected:(BOOL)newConnected
{
	if (connected != newConnected)
	{
		connected = newConnected;
		
		if (!connected && [(id)delegate respondsToSelector:@selector(remoteDisconnected:)])
			[(id)delegate performSelectorOnMainThread:@selector(remoteDisconnected:) withObject:self waitUntilDone:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:kShowStatusInStatusWindowNotification
															object:self];
	}
}

- (void)shutdown
{
	self.connected = NO;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark NSCoding
// -----------------------------------------------------------------------------
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super init]) != nil)
	{
		clientName = [[aDecoder decodeObjectForKey:@"clientName"] retain];
		clientVersion = [[aDecoder decodeObjectForKey:@"clientVersion"] retain];
		clientOSName = [[aDecoder decodeObjectForKey:@"clientOSName"] retain];
		clientOSVersion = [[aDecoder decodeObjectForKey:@"clientOSVersion"] retain];
		clientDevice = [[aDecoder decodeObjectForKey:@"clientDevice"] retain];
		clientUDID = [[aDecoder decodeObjectForKey:@"clientUDID"] retain];
		parentIndexesStack = [[aDecoder decodeObjectForKey:@"parentIndexes"] retain];
		filenames = [[aDecoder decodeObjectForKey:@"filenames"] retain];
		if (filenames == nil)
			filenames = [[NSMutableSet alloc] init];
		functionNames = [[aDecoder decodeObjectForKey:@"functionNames"] retain];
		if (functionNames == nil)
			functionNames = [[NSMutableSet alloc] init];
		objc_setAssociatedObject(aDecoder, &sConnectionAssociatedObjectKey, self, OBJC_ASSOCIATION_ASSIGN);
		messages = [[aDecoder decodeObjectForKey:@"messages"] retain];
		reconnectionCount = [aDecoder decodeIntForKey:@"reconnectionCount"];
		restoredFromSave = YES;
		
		// we need a messageProcessingQueue just for the ability to add/insert marks
		// when user does post-mortem investigation
		messageProcessingQueue = dispatch_queue_create("com.florentpillet.nslogger.messageProcessingQueue", NULL);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	if (clientName != nil)
		[aCoder encodeObject:clientName forKey:@"clientName"];
	if (clientVersion != nil)
		[aCoder encodeObject:clientVersion forKey:@"clientVersion"];
	if (clientOSName != nil)
		[aCoder encodeObject:clientOSName forKey:@"clientOSName"];
	if (clientOSVersion != nil)
		[aCoder encodeObject:clientOSVersion forKey:@"clientOSVersion"];
	if (clientDevice != nil)
		[aCoder encodeObject:clientDevice forKey:@"clientDevice"];
	if (clientUDID != nil)
		[aCoder encodeObject:clientUDID forKey:@"clientUDID"];
	[aCoder encodeObject:filenames forKey:@"filenames"];
	[aCoder encodeObject:functionNames forKey:@"functionNames"];
	[aCoder encodeInt:reconnectionCount forKey:@"reconnectionCount"];
	@synchronized (messages)
	{
		[aCoder encodeObject:messages forKey:@"messages"];
		[aCoder encodeObject:parentIndexesStack forKey:@"parentIndexes"];
	}
}

@end
