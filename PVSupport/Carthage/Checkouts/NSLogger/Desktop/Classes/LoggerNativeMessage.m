/*
 * LoggerNativeMessage.m
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
#import "LoggerNativeMessage.h"
#import "LoggerCommon.h"

@implementation LoggerNativeMessage

- (id)initWithData:(NSData *)data connection:(LoggerConnection *)aConnection
{
	if ((self = [super init]) != nil)
	{
		// decode message contents
		uint8_t *p = (uint8_t *)[data bytes];
		uint16_t partCount;
		memcpy(&partCount, p, 2);
		partCount = ntohs(partCount);
		p += 2;
		while (partCount--)
		{
			uint8_t partKey = *p++;
			uint8_t partType = *p++;
			uint32_t partSize;
			if (partType == PART_TYPE_INT16)
				partSize = 2;
			else if (partType == PART_TYPE_INT32)
				partSize = 4;
			else if (partType == PART_TYPE_INT64)
				partSize = 8;
			else
			{
				memcpy(&partSize, p, 4);
				p += 4;
				partSize = ntohl(partSize);
			}
			id part = nil;
			uint32_t value32 = 0;
			uint64_t value64 = 0;
			if (partSize > 0)
			{
				if (partType == PART_TYPE_STRING)
				{
					part = [[NSString alloc] initWithBytes:p length:partSize encoding:NSUTF8StringEncoding];
				}
				else if (partType == PART_TYPE_BINARY || partType == PART_TYPE_IMAGE)
				{
					part = [[NSData alloc] initWithBytes:p length:partSize];
				}
				else if (partType == PART_TYPE_INT16)
				{
					value32 = (((uint32_t)p[0]) << 8) | (uint32_t)p[1];
				}
				else if (partType == PART_TYPE_INT32)
				{
					value32 = (((uint32_t)p[0]) << 24) | (((uint32_t)p[1]) << 16) | (((uint32_t)p[2]) << 8) | (uint32_t)p[3];
				}
				else if (partType == PART_TYPE_INT64)
				{
					memcpy(&value64, p, 8);
					value64 = CFSwapInt64BigToHost(value64);
				}
				p += partSize;
			}
			switch (partKey)
			{
				case PART_KEY_MESSAGE_TYPE:
					type = (short)value32;
					break;
				case PART_KEY_MESSAGE_SEQ:
					sequence = value32;
					break;
				case PART_KEY_TIMESTAMP_S:			// timestamp with seconds-level resolution
					timestamp.tv_sec = (partType == PART_TYPE_INT64) ? (__darwin_time_t)value64 : (__darwin_time_t)value32;
					break;
				case PART_KEY_TIMESTAMP_MS:			// millisecond part of the timestamp (optional)
					timestamp.tv_usec = ((partType == PART_TYPE_INT64) ? (__darwin_suseconds_t)value64 : (__darwin_suseconds_t)value32) * 1000;
					break;
				case PART_KEY_TIMESTAMP_US:			// microsecond part of the timestamp (optional)
					timestamp.tv_usec = (partType == PART_TYPE_INT64) ? (__darwin_suseconds_t)value64 : (__darwin_suseconds_t)value32;
					break;
				case PART_KEY_THREAD_ID:
					if (partType == PART_TYPE_INT32)
						threadID = [[NSString alloc] initWithFormat:@"Thread 0x%x", value32];
					else if (partType == PART_TYPE_INT64)
						threadID = [[NSString alloc] initWithFormat:@"Thread 0x%qx", value64];
					else if (partType == PART_TYPE_STRING)
						threadID = [part retain];
					else
						threadID = @"";
					break;
				case PART_KEY_TAG:
					self.tag = (NSString *)part;
					break;
				case PART_KEY_LEVEL:
					if (partType == PART_TYPE_INT16 || partType == PART_TYPE_INT32)
						level = (short)value32;
					else if (partType == PART_TYPE_INT64)
						level = (short)value64;
					break;
				case PART_KEY_MESSAGE:
					self.message = part;
					if (partType == PART_TYPE_STRING)
						contentsType = kMessageString;
					else if (partType == PART_TYPE_BINARY)
						contentsType = kMessageData;
					else if (partType == PART_TYPE_IMAGE)
						contentsType = kMessageImage;
					break;
				case PART_KEY_IMAGE_WIDTH:
					if (partType == PART_TYPE_INT16 || partType == PART_TYPE_INT32)
						imageSize.width = value32;
					else if (partType == PART_TYPE_INT64)
						imageSize.width = value64;
					break;
				case PART_KEY_IMAGE_HEIGHT:
					if (partType == PART_TYPE_INT16 || partType == PART_TYPE_INT32)
						imageSize.height = value32;
					else if (partType == PART_TYPE_INT64)
						imageSize.height = value64;
					break;
				case PART_KEY_FILENAME:
					if (part != nil)
						[self setFilename:part connection:aConnection];
					break;
				case PART_KEY_FUNCTIONNAME:
					if (part!= nil)
						[self setFunctionName:part connection:aConnection];
					break;
				case PART_KEY_LINENUMBER:
					if (partType == PART_TYPE_INT16 || partType == PART_TYPE_INT32)
						lineNumber = value32;
					else if (partType == PART_TYPE_INT64)
						lineNumber = (int)value64;
					break;
				default: {
					// all other keys are automatically added to the parts dictionary
					if (parts == nil)
						parts = [[NSMutableDictionary alloc] init];
					NSNumber *partKeyNumber = [[NSNumber alloc] initWithUnsignedInteger:partKey];
					if (partType == PART_TYPE_INT32)
						part = [[NSNumber alloc] initWithInteger:value32];
					else if (partType == PART_TYPE_INT64)
						part = [[NSNumber alloc] initWithUnsignedLongLong:value64];
					if (part != nil)
						[parts setObject:part forKey:partKeyNumber];
					[partKeyNumber release];
					break;
				}
			}
			[part release];
		}
	}
#if 0
	// Debug tool to log the original image (until we have DnD)
	if (type == LOGMSG_TYPE_LOG && contentsType == kMessageImage)
	{
		// detect the image type to set the proper extension
		NSString *ext = @"png";
		CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)message, NULL);
		if (imageSource != NULL)
		{
			CFStringRef imageType = CGImageSourceGetType(imageSource);
			if (imageType != NULL)
			{
				NSDictionary *typeDef = (NSDictionary *)UTTypeCopyDeclaration(imageType);
				NSDictionary *spec = [typeDef objectForKey:(id)kUTTypeTagSpecificationKey];
				NSArray *exts = [spec objectForKey:@"public.filename-extension"];
				if (exts != nil && [exts isKindOfClass:[NSArray class]] && [exts count] && [[exts lastObject] length])
					ext = [[[exts lastObject] retain] autorelease];
				[typeDef release];
			}
			CFRelease(imageSource);
		}
		NSString *fn = [NSString stringWithFormat:@"%d.%@", sequence, ext];
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fn];
		[(NSData *)message writeToFile:path atomically:NO];
	}
#endif
	return self;
}

@end
