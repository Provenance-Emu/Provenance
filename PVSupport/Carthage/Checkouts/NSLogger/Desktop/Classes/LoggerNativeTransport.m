/*
 * LoggerNativeTransport.m
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

/*
 * This implements NATIVE (NSLogger binary format) transport decoding over TCP
 */

#import "LoggerTCPTransport.h"
#import "LoggerNativeTransport.h"
#import "LoggerConnection.h"
#import "LoggerTCPConnection.h"
#import "LoggerMessage.h"
#import "LoggerCommon.h"
#import "LoggerNativeMessage.h"
#import "LoggerAppDelegate.h"

@interface LoggerNativeTransport ()
- (NSString *)clientInfoStringForMessage:(LoggerMessage *)message;

- (void)dumpBytes:(uint8_t *)bytes length:(int)dataLen;
@end

@implementation LoggerNativeTransport

- (NSString *)transportInfoString
{
	// returns the text string displayed in the Logger Status window
	if (publishBonjourService)
	{
		NSString *name = bonjourServiceName;
		if (![name length])
			name = [bonjourService name];
		if ([name length])
			return [NSString stringWithFormat:NSLocalizedString(@"Bonjour (%@, port %d%s)", @"Named Bonjour transport info string"),
					name,
					listenerPort,
					secure ? ", SSL" : ""];
		return [NSString stringWithFormat:NSLocalizedString(@"Bonjour (port %d%s)", @"Bonjour transport (default name) info string"),
				listenerPort,
				secure ? ", SSL" : ""];
	}
	return [NSString stringWithFormat:NSLocalizedString(@"TCP/IP (port %d%s)", @"TCP/IP transport info string"),
			listenerPort,
			secure ? ", SSL" : ""];
}

- (NSString *)bonjourServiceName
{
	// returns the service name that we use when publishing over Bonjour
	return [[NSUserDefaults standardUserDefaults] objectForKey:kPrefBonjourServiceName];
}

- (NSString *)bonjourServiceType
{
	// returns the Bonjour service type, depends on the exact type of service (encrypted or not)
	return (NSString *)(secure ? LOGGER_SERVICE_TYPE_SSL : LOGGER_SERVICE_TYPE);
}

- (NSInteger)tcpPort
{
	return [[[NSUserDefaults standardUserDefaults] objectForKey:kPrefDirectTCPIPResponderPort] integerValue];
}

- (LoggerConnection *)connectionWithInputStream:(NSInputStream *)is outputStream:(NSOutputStream *)os clientAddress:(NSData *)addr
{
    return [[[LoggerTCPConnection alloc] initWithInputStream:is outputStream:os clientAddress:addr] autorelease];
}

- (void)processIncomingData:(LoggerTCPConnection *)cnx
{
	NSMutableArray *msgs = [NSMutableArray array];
	//[self dumpBytes:cnx.tmpBuf length:numBytes];
	NSUInteger bufferLength = [cnx.buffer length];
	while (bufferLength > 4)
	{
		// check whether we have a full message
		uint32_t length;
		[cnx.buffer getBytes:&length length:4];
		length = ntohl(length);
		if (bufferLength < (length + 4))
			break;

		// get one message
		CFDataRef subset = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,
													   (unsigned char *) [cnx.buffer bytes] + 4,
													   length,
													   kCFAllocatorNull);
		if (subset != NULL)
		{
			// we receive a ClientInfo message only when the client connects. Once we get this message,
			// the connection is considered being "live" (we need to wait a bit to let SSL negotiation to
			// take place, and not open a window if it fails).
			LoggerMessage *message = [[LoggerNativeMessage alloc] initWithData:(NSData *) subset connection:cnx];
			CFRelease(subset);
			if (message.type == LOGMSG_TYPE_CLIENTINFO)
			{
				message.message = [self clientInfoStringForMessage:message];
				message.threadID = @"";
				[cnx clientInfoReceived:message];
				[self attachConnectionToWindow:cnx];
			}
			else
			{
				[msgs addObject:message];
			}
			[message release];
		}
		[cnx.buffer replaceBytesInRange:NSMakeRange(0, length + 4) withBytes:NULL length:0];
		bufferLength = [cnx.buffer length];
	}

	if ([msgs count])
		[cnx messagesReceived:msgs];
}

- (NSString *)clientInfoStringForMessage:(LoggerMessage *)message
{
	NSDictionary *parts = message.parts;
	NSString *clientName = [parts objectForKey:@(PART_KEY_CLIENT_NAME)];
	NSString *clientVersion = [parts objectForKey:@(PART_KEY_CLIENT_VERSION)];
	NSString *clientAppInfo = @"";
	if ([clientName length])
		clientAppInfo = [NSString stringWithFormat:NSLocalizedString(@"Client connected: %@ %@", @""),
						 clientName,
						 clientVersion ? clientVersion : @""];

	NSString *osName = [parts objectForKey:@(PART_KEY_OS_NAME)];
	NSString *osVersion = [parts objectForKey:@(PART_KEY_OS_VERSION)];
	NSString *osInfo = @"";
	if ([osName length])
		osInfo = [NSString stringWithFormat:NSLocalizedString(@"%@ (%@ %@)", @""),
				  [clientAppInfo length] ? @"" : NSLocalizedString(@"Client connected", @""),
				  osName,
				  osVersion ? osVersion : @""];

	NSString *hardware = [parts objectForKey:@(PART_KEY_CLIENT_MODEL)];
	NSString *hardwareInfo = @"";
	if ([hardware length])
		hardwareInfo = [NSString stringWithFormat:NSLocalizedString(@"\nHardware: %@", @""), hardware];

	NSString *uniqueID = [parts objectForKey:@(PART_KEY_UNIQUEID)];
	NSString *uniqueIDString = @"";
	if ([uniqueID length])
		uniqueIDString = [NSString stringWithFormat:NSLocalizedString(@"\nUDID: %@", @""), uniqueID];
	NSString *header = @"";
	if (clientAppInfo == nil)
		header = NSLocalizedString(@"Client connected\n", @"");
	return [NSString stringWithFormat:@"%@%@%@%@%@", header, clientAppInfo, osInfo, hardwareInfo, uniqueIDString];
}

- (void)dumpBytes:(uint8_t *)bytes length:(int)dataLen
{
	// Code to debug the incoming data format
	NSMutableString *s = [[NSMutableString alloc] init];
	NSUInteger offset = 0;
	NSString *str;
	char buffer[1+6+16*3+1+16+1+1+1];
	buffer[0] = '\0';
	const unsigned char *q = bytes;
	if (dataLen == 1)
		[s appendString:NSLocalizedString(@"Raw data, 1 byte:\n", @"")];
	else
		[s appendFormat:NSLocalizedString(@"Raw data, %u bytes:\n", @""), dataLen];
	while (dataLen)
	{
		int i, b = sprintf(buffer," %04x: ", (int)offset);
		for (i=0; i < 16 && i < dataLen; i++)
			sprintf(&buffer[b+3*i], "%02x ", (int)q[i]);
		for (int j=i; j < 16; j++)
			strcat(buffer, "   ");

		b = strlen(buffer);
		buffer[b++] = '\'';
		for (i=0; i < 16 && i < dataLen; i++, q++)
		{
			if (*q >= 32 && *q < 128)
				buffer[b++] = *q;
			else
				buffer[b++] = ' ';
		}
		for (int j=i; j < 16; j++)
			buffer[b++] = ' ';
		buffer[b++] = '\'';
		buffer[b++] = '\n';
		buffer[b] = 0;

		str = [[NSString alloc] initWithBytes:buffer length:strlen(buffer) encoding:NSISOLatin1StringEncoding];
		[s appendString:str];
		[str release];

		dataLen -= i;
		offset += i;
	}
	NSLog(@"Received bytes:\n%@", s);
	[s release];
}

@end
