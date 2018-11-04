/*
 * LoggerIPConnection.h
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
#include <arpa/inet.h>
#import "LoggerIPConnection.h"

@implementation LoggerIPConnection

- (NSString *)clientAddressDescription
{
	if ([clientAddress length] == sizeof(struct sockaddr_in6))
	{
		struct sockaddr_in6 addr6;
		[clientAddress getBytes:&addr6 length:sizeof(addr6)];
		return [NSString stringWithFormat:@"%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
				addr6.sin6_addr.__u6_addr.__u6_addr16[0],
				addr6.sin6_addr.__u6_addr.__u6_addr16[1],
				addr6.sin6_addr.__u6_addr.__u6_addr16[2],
				addr6.sin6_addr.__u6_addr.__u6_addr16[3],
				addr6.sin6_addr.__u6_addr.__u6_addr16[4],
				addr6.sin6_addr.__u6_addr.__u6_addr16[5],
				addr6.sin6_addr.__u6_addr.__u6_addr16[6],
				addr6.sin6_addr.__u6_addr.__u6_addr16[7]];
	}

	struct sockaddr_in addr4;
	[clientAddress getBytes:&addr4 length:sizeof(addr4)];
	char *inetname = inet_ntoa(addr4.sin_addr);
	if (inetname != NULL)
		return [NSString stringWithCString:inetname encoding:NSASCIIStringEncoding];

	return nil;
}

@end
