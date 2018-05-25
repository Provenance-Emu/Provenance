/*
 *
 * Modified BSD license.
 *
 * Based on
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com>
 * Copyright (c) 2008 Loren Brichter,
 *
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
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


#import "LoggerMessageFormatter.h"
#import "LoggerMessage.h"
#import "LoggerCommon.h"
#include <sys/time.h>
#include "NullStringCheck.h"

@implementation LoggerMessageFormatter

+(NSString *)formatTimestamp:(struct timeval * const)aTimestamp
{
	if(aTimestamp == NULL)
		return nil;

	time_t sec = aTimestamp->tv_sec;
	struct tm *t = localtime(&sec);
	NSString *timestampStr;

	if (aTimestamp->tv_usec == 0)
		timestampStr = [NSString stringWithFormat:@"%02d:%02d:%02d", t->tm_hour, t->tm_min, t->tm_sec];
	else
		timestampStr = [NSString stringWithFormat:@"%02d:%02d:%02d.%03d", t->tm_hour, t->tm_min, t->tm_sec, aTimestamp->tv_usec / 1000];
	
	return timestampStr;
}

+(NSString *)formatFileFuncLine:(LoggerMessage *)message
{
	NSString *s = @"";
	BOOL hasFilename = !IS_NULL_STRING(message.filename);
	BOOL hasFunction = !IS_NULL_STRING(message.functionName);
	
	if (hasFunction && hasFilename)
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:@"%@ (%@:%d)", message.functionName, [message.filename lastPathComponent], message.lineNumber];
		else
			s = [NSString stringWithFormat:@"%@ (%@)", message.functionName, [message.filename lastPathComponent]];
	}
	else if (hasFunction)
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:NSLocalizedString(@"%@ (line %d)", @""), message.functionName, message.lineNumber];
		else
			s = message.functionName;
	}
	else
	{
		if (message.lineNumber)
			s = [NSString stringWithFormat:@"%@:%d", [message.filename lastPathComponent], message.lineNumber];
		else
			s = [message.filename lastPathComponent];
	}
	
	return s;
}

+ (NSString *)formatClientInfoMessage:(LoggerMessage *)message
{
	NSDictionary *parts = message.parts;
	NSString *clientName = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_NAME]];
	NSString *clientVersion = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_VERSION]];
	NSString *clientAppInfo = @"";
	if ([clientName length])
		clientAppInfo = [NSString stringWithFormat:NSLocalizedString(@"Client connected: %@ %@", @""),
						 clientName,
						 clientVersion ? clientVersion : @""];
	
	NSString *osName = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_OS_NAME]];
	NSString *osVersion = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_OS_VERSION]];
	NSString *osInfo = @"";
	if ([osName length])
		osInfo = [NSString stringWithFormat:NSLocalizedString(@"%@ (%@ %@)", @""),
				  [clientAppInfo length] ? @"" : NSLocalizedString(@"Client connected", @""),
				  osName,
				  osVersion ? osVersion : @""];
	
	NSString *hardware = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_CLIENT_MODEL]];
	NSString *hardwareInfo = @"";
	if ([hardware length])
		hardwareInfo = [NSString stringWithFormat:NSLocalizedString(@"\nHardware: %@", @""), hardware];
	
	NSString *uniqueID = [parts objectForKey:[NSNumber numberWithInteger:PART_KEY_UNIQUEID]];
	NSString *uniqueIDString = @"";
	if ([uniqueID length])
		uniqueIDString = [NSString stringWithFormat:NSLocalizedString(@"\nUDID: %@", @""), uniqueID];
	NSString *header = @"";
	if (clientAppInfo == nil)
		header = NSLocalizedString(@"Client connected\n", @"");

	return [NSString stringWithFormat:@"%@%@%@%@%@", header, clientAppInfo, osInfo, hardwareInfo, uniqueIDString];
}

+(NSString *)formatAndTruncateDisplayMessage:(LoggerMessage * const)aMessage truncated:(BOOL *)isTruncated
{
	NSString *displayMessage = nil;

	switch (aMessage.contentsType)
	{
		case kMessageString:{
			
			// in case the message text is empty, use the function name as message text
			// this is typically used to record a waypoint in the code flow
			NSString *message = nil;
			if (![aMessage.message length] && [aMessage.functionName length])
			{
				message = aMessage.functionName;
			}
			else
			{
				message = aMessage.message;
			}
			
			// very long messages can't be displayed entirely. No need to compute their full size,
			// it slows down the UI to no avail. Just cut the string to a reasonable size, and take
			// the calculations from here.
			if ([message length] > MSG_TRUNCATE_THREADHOLD_LENGTH)
			{
				displayMessage = [message substringToIndex:MSG_TRUNCATE_THREADHOLD_LENGTH];
				*isTruncated = TRUE;
			}
			else
			{
				displayMessage = message;
			}

			break;
		}
		case kMessageData:{
			NSData *message = aMessage.message;
			assert([message isKindOfClass:[NSData class]]);
			
			// convert NSData block to hex-ascii strings
			NSMutableString *strings = [[NSMutableString alloc] init];
			NSUInteger offset = 0, dataLen = [message length],line_count = 0;
			NSString *str;
			char buffer[1+6+16*3+1+16+1+1+1];
			buffer[0] = '\0';
			const unsigned char *q = [message bytes];
			if (dataLen == 1)
				[strings appendString:NSLocalizedString(@"Raw data, 1 byte:\n", nil)];
			else
				[strings appendFormat:NSLocalizedString(@"Raw data, %u bytes:\n", nil), dataLen];
			while (dataLen)
			{
				if (MAX_DATA_LINES <= line_count)
				{
					//we've reached the maximum length. bailout
					*isTruncated = TRUE;
					break;
				}

				int i, b = sprintf(buffer," %04lx: ", (unsigned long)offset);
				for (i=0; i < 16 && i < dataLen; i++)
					sprintf(&buffer[b+3*i], "%02x ", (int)q[i]);
				for (int j=i; j < 16; j++)
					strcat(buffer, "   ");
				
				b = (int)strlen(buffer);
				buffer[b++] = '\'';
				for (i=0; i < 16 && i < dataLen; i++)
				{
					if (q[i] >= 32 && q[i] < 128)
						buffer[b++] = q[i];
					else
						buffer[b++] = ' ';
				}
				for (int j=i; j < 16; j++)
					buffer[b++] = ' ';
				buffer[b++] = '\'';
				buffer[b++] = '\n';
				buffer[b] = 0;
				
				str = [[NSString alloc] initWithBytes:buffer length:strlen(buffer) encoding:NSISOLatin1StringEncoding];
				[strings appendString:str];
				[str release];

				line_count++;
				dataLen -= i;
				offset += i;
				q += i;
			}
			displayMessage = [strings autorelease];
			break;
		}

		case kMessageImage:
		default:{
			break;
		}
	}

	return displayMessage;
}
@end
