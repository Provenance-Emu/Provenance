/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 2010-2012 Florent Pillet,
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

#import "LoggerNativeLegacyTransport.h"
#include <dns_sd.h>
#include <dns_util.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>

#import "LoggerTCPConnection.h"
#import "LoggerNativeMessage.h"

@interface LoggerNativeLegacyTransport()
static void
ServiceRegisterCallback(DNSServiceRef,DNSServiceFlags,DNSServiceErrorType,const char*,const char*,const char*,void*);
static void
ServiceRegisterSocketCallBack(CFSocketRef,CFSocketCallBackType,CFDataRef,const void*,void*);
- (void)didNotRegisterWithError:(DNSServiceErrorType)errorCode;
- (void)didRegisterWithDomain:(const char *)domain name:(const char *)name;

- (void)dumpBytes:(uint8_t *)bytes length:(int)dataLen;
@end


@implementation LoggerNativeLegacyTransport{
	BOOL				_useBluetooth;
	DNSServiceRef		_sdServiceRef;
	CFSocketRef			_sdServiceSocket;	// browser service socket to tie in the current runloop
	CFRunLoopSourceRef	_sdServiceRunLoop;	// browser service callback runloop
}
@synthesize useBluetooth = _useBluetooth;

static void
ServiceRegisterCallback(DNSServiceRef			sdRef,
						DNSServiceFlags			flags,
						DNSServiceErrorType		errorCode,
						const char				*name,
						const char				*regtype,
						const char				*domain,
						void					*context)

{
	LoggerNativeLegacyTransport *callbackSelf = (LoggerNativeLegacyTransport *) context;
    assert([callbackSelf isKindOfClass:[LoggerNativeLegacyTransport class]]);
    assert(sdRef == callbackSelf->_sdServiceRef);
    assert(flags & kDNSServiceFlagsAdd);
	
    if (errorCode == kDNSServiceErr_NoError)
	{
		// We're assuming SRV records over unicast DNS here, so the first result packet we get
        // will contain all the information we're going to get.  In a more dynamic situation
        // (for example, multicast DNS or long-lived queries in Back to My Mac) we'd would want
        // to leave the query running.
        
		// we only need to find out whether the service is registered. unregsitering is not concerned.
		if (flags & kDNSServiceFlagsAdd)
		{
            [callbackSelf didRegisterWithDomain:domain name:name];
        }
		
    } else {
        [callbackSelf didNotRegisterWithError:errorCode];
    }
}


// A CFSocket callback for Browsing. This runs when we get messages from mDNSResponder
// regarding our DNSServiceRef.  We just turn around and call DNSServiceProcessResult,
// which does all of the heavy lifting (and would typically call BrowserServiceReply).
static void
ServiceRegisterSocketCallBack(CFSocketRef			socket,
							  CFSocketCallBackType	type,
							  CFDataRef				address,
							  const void			*data,
							  void					*info)
{
	DNSServiceErrorType errorCode = kDNSServiceErr_NoError;
	
	LoggerNativeLegacyTransport *callbackSelf = (LoggerNativeLegacyTransport *)info;
	assert(callbackSelf != NULL);
	
	errorCode = DNSServiceProcessResult(callbackSelf->_sdServiceRef);
    if (errorCode != kDNSServiceErr_NoError)
	{
        [callbackSelf didNotRegisterWithError:errorCode];
    }
}

//------------------------------------------------------------------------------
#pragma mark - DNS-SD callback response
//------------------------------------------------------------------------------
- (void)didNotRegisterWithError:(DNSServiceErrorType)errorCode
{
	[self shutdown];
	
	switch (errorCode)
	{
		case kDNSServiceErr_NameConflict:{
			self.failureReason = NSLocalizedString(@"Duplicate Bonjour service name on your network", @"");
			break;
		}
		case kDNSServiceErr_BadParam:{
			self.failureReason = NSLocalizedString(@"Bonjour bad argument - please report bug.", @"");
			break;
		}
		case kDNSServiceErr_Invalid:{
			self.failureReason = NSLocalizedString(@"Bonjour invalid configuration - please report bug.", @"");
			break;
		}
		default:{
			self.failureReason = [NSString stringWithFormat:NSLocalizedString(@"Bonjour error %d", @""), errorCode];
			break;
		}
	}
	
	MTLog(@"service failed %@",self.failureReason);
	failed = YES;
	[self reportErrorToManager:[self status]];
}

- (void)didRegisterWithDomain:(const char *)domain name:(const char *)name
{
	MTLog(@"service registration success domain[%s]  name[%s]",domain,name);
	
	ready = YES;
	[self reportStatusToManager:[self status]];
}

//------------------------------------------------------------------------------
#pragma mark - Inherited Methods
//------------------------------------------------------------------------------
-(void)closeSockets
{
	if(self->_sdServiceRunLoop != NULL)
	{
		CFRunLoopSourceInvalidate(self->_sdServiceRunLoop);
		CFRelease(self->_sdServiceRunLoop);
		self->_sdServiceRunLoop = NULL;
	}
	
	if (self->_sdServiceSocket != NULL)
	{
        CFSocketInvalidate(self->_sdServiceSocket);
        CFRelease(self->_sdServiceSocket);
        self->_sdServiceSocket = NULL;
    }
	
	// stop DNS-SD service, stop Bonjour service
	if (self->_sdServiceRef != NULL)
	{
        DNSServiceRefDeallocate(self->_sdServiceRef);
        self->_sdServiceRef = NULL;
    }
	
	// close listener sockets (removing input sources)
	if (listenerSocket_ipv4)
	{
		CFSocketInvalidate(listenerSocket_ipv4);
		CFRelease(listenerSocket_ipv4);
		listenerSocket_ipv4 = NULL;
	}
	if (listenerSocket_ipv6)
	{
		CFSocketInvalidate(listenerSocket_ipv6);
		CFRelease(listenerSocket_ipv6);
		listenerSocket_ipv6 = NULL;
	}
}

- (BOOL)setup
{
	int yes = 1;
	DNSServiceErrorType errorType	= kDNSServiceErr_NoError;
	int fd = 0;
	CFSocketContext context = { 0, (void *)self, NULL, NULL, NULL };
	CFOptionFlags socketFlag = 0;
	
	@try
	{
		// create sockets
		listenerSocket_ipv4 = CFSocketCreate(kCFAllocatorDefault,
											 PF_INET,
											 SOCK_STREAM,
											 IPPROTO_TCP,
											 kCFSocketAcceptCallBack,
											 &AcceptSocketCallback,
											 &context);
		
		listenerSocket_ipv6 = CFSocketCreate(kCFAllocatorDefault,
											 PF_INET6,
											 SOCK_STREAM,
											 IPPROTO_TCP,
											 kCFSocketAcceptCallBack,
											 &AcceptSocketCallback,
											 &context);
		
		if (listenerSocket_ipv4 == NULL || listenerSocket_ipv6 == NULL)
		{
			@throw [NSException
					exceptionWithName:@"CFSocketCreate"
					reason:NSLocalizedString(@"Failed creating listener socket (CFSocketCreate failed)", nil)
					userInfo:nil];
		}
		
		// set socket options & addresses
		setsockopt(CFSocketGetNative(listenerSocket_ipv4), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
		setsockopt(CFSocketGetNative(listenerSocket_ipv6), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
		
		// set up the IPv4 endpoint; if port is 0, this will cause the kernel to choose a port for us
		struct sockaddr_in addr4;
		memset(&addr4, 0, sizeof(addr4));
		addr4.sin_len = sizeof(addr4);
		addr4.sin_family = AF_INET;
		addr4.sin_port = htons(listenerPort);
		addr4.sin_addr.s_addr = htonl(INADDR_ANY);
		NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
		
	    if (CFSocketSetAddress(listenerSocket_ipv4, (CFDataRef)address4) != kCFSocketSuccess)
		{
			@throw [NSException
					exceptionWithName:@"CFSocketSetAddress"
					reason:NSLocalizedString(@"Failed setting IPv4 socket address", nil)
					userInfo:nil];
		}
		
		if (listenerPort == 0)
		{
			// now that the binding was successful, we get the port number
			// -- we will need it for the v6 endpoint and for NSNetService
			NSData *addr = [(NSData *)CFSocketCopyAddress(listenerSocket_ipv4) autorelease];
			memcpy(&addr4, [addr bytes], [addr length]);
			listenerPort = ntohs(addr4.sin_port);
		}
		
	    // set up the IPv6 endpoint
		struct sockaddr_in6 addr6;
		memset(&addr6, 0, sizeof(addr6));
		addr6.sin6_len = sizeof(addr6);
		addr6.sin6_family = AF_INET6;
		addr6.sin6_port = htons(listenerPort);
		memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
		NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)];
		
		if (CFSocketSetAddress(listenerSocket_ipv6, (CFDataRef)address6) != kCFSocketSuccess)
		{
			@throw [NSException
					exceptionWithName:@"CFSocketSetAddress"
					reason:NSLocalizedString(@"Failed setting IPv6 socket address", nil)
					userInfo:nil];
		}
		
		// set up the run loop sources for the sockets
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listenerSocket_ipv4, 0);
		CFRunLoopAddSource(rl, source4, kCFRunLoopCommonModes);
		CFRelease(source4);
		
		CFRunLoopSourceRef source6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listenerSocket_ipv6, 0);
		CFRunLoopAddSource(rl, source6, kCFRunLoopCommonModes);
		CFRelease(source6);
		
		// register Bonjour service
		if (publishBonjourService)
		{
			BOOL publishingResult = NO;
			
			// The service type is nslogger-ssl (now the default), or nslogger for backwards
			// compatibility with pre-1.0.
			//NSString *serviceType = (NSString *)(secure ? LOGGER_SERVICE_TYPE_SSL : LOGGER_SERVICE_TYPE);
			NSString *serviceType = [self bonjourServiceType];

			// when bonjour is on, and bluetooth to be used
			DNSServiceFlags serviceFlag = (_useBluetooth) ? kDNSServiceFlagsIncludeP2P : 0;
			
			// The service name is either the one defined in the prefs, of by default
			// the local computer name (as defined in the sharing prefs panel
			// (see Technical Q&A QA1228 http://developer.apple.com/library/mac/#qa/qa2001/qa1228.html )
			NSString *serviceName = [[LoggerPreferenceManager sharedPrefManager] bonjourServiceName];
			BOOL useDefaultServiceName = (serviceName == nil || ![serviceName isKindOfClass:[NSString class]]);
			if (useDefaultServiceName)
				serviceName = @"";
			
			[serviceName retain];
			[bonjourServiceName release];
			bonjourServiceName = serviceName;
			
			// added in 1.5: let clients know that we have customized our service name and that they should connect to us
			// only if their own settings match our name
			NSData *textRecord = nil;
			if (useDefaultServiceName){
				textRecord = [[NSNetService dataFromTXTRecordDictionary:@{@"filterClients": @"1"}] retain];
			}
			
			errorType =
			DNSServiceRegister(&(self->_sdServiceRef),		// sdRef
							   serviceFlag,					// flags
							   kDNSServiceInterfaceIndexAny,// interfaceIndex. kDNSServiceInterfaceIndexP2P does not have meanning when serving
							   bonjourServiceName.UTF8String,// name
							   serviceType.UTF8String,		// regtype
							   NULL,						// domain
							   NULL,						// host
							   htons(listenerPort),			// port. just for bt init
							   (useDefaultServiceName)?[textRecord length]:0,  // txtLen
							   (useDefaultServiceName)?[textRecord bytes]:NULL,// txtRecord
							   ServiceRegisterCallback,		// callBack
							   (void *)(self)				// context
							   );

			if (useDefaultServiceName){
				[textRecord release],textRecord = nil;
			}
			
			if (errorType == kDNSServiceErr_NoError)
			{
				fd = DNSServiceRefSockFD(self->_sdServiceRef);
				if(0 <= fd)
				{
					self->_sdServiceSocket =
					CFSocketCreateWithNative(NULL,
											 fd,
											 kCFSocketReadCallBack,
											 ServiceRegisterSocketCallBack,
											 &context);
					if(self->_sdServiceSocket != NULL)
					{
						socketFlag = CFSocketGetSocketFlags(self->_sdServiceSocket);
						socketFlag = socketFlag &~ (CFOptionFlags)kCFSocketCloseOnInvalidate;
						CFSocketSetSocketFlags(self->_sdServiceSocket,socketFlag);
						
						self->_sdServiceRunLoop = CFSocketCreateRunLoopSource(NULL,self->_sdServiceSocket, 0);
						CFRunLoopAddSource(CFRunLoopGetCurrent(), self->_sdServiceRunLoop, kCFRunLoopCommonModes);
						
						publishingResult = YES;
					}
				}
			}
			
			if(!publishingResult)
			{
				@throw
				[NSException
				 exceptionWithName:@"DNSServiceRegister"
				 reason:[NSString
						 stringWithFormat:@"%@\n\n%@"
						 ,NSLocalizedString(@"Failed announce Bonjour service (DNSServiceRegister failed)", nil)
						 ,@"Transport failed opening - unknown reason"]
				 userInfo:nil];
			}
		}
		else
		{
			ready = YES;
		}
	}
	@catch (NSException * e)
	{
		failed = YES;
		
		if (publishBonjourService)
			self.failureReason = NSLocalizedString(@"Failed creating sockets for Bonjour%s service.", @"");
		else
			self.failureReason = [NSString stringWithFormat:NSLocalizedString(@"Failed listening on port %d (port busy?)",@""), listenerPort];
		
		[self reportErrorToManager:[self status]];
		
		[self closeSockets];
		
		return NO;
	}
	@finally
	{
		[self reportStatusToManager:[self status]];
	}
	return YES;
}


//------------------------------------------------------------------------------
#pragma mark - Subclass Obligation
//------------------------------------------------------------------------------
- (NSDictionary *)status
{
	return
		@{kTransportTag:[NSNumber numberWithInt:[self tag]]
	   ,kTransportSecure:[NSNumber numberWithBool:[self secure]]
	   ,kTransportReady:[NSNumber numberWithBool:[self ready]]
	   ,kTransportActivated:[NSNumber numberWithBool:[self active]]
	   ,kTransportFailed:[NSNumber numberWithBool:[self failed]]
	   ,kTransportBluetooth:[NSNumber numberWithBool:[self useBluetooth]]
	   ,kTransportBonjour:[NSNumber numberWithBool:[self publishBonjourService]]
	   ,kTransportInfoString:[self transportInfoString]
	   ,kTransportStatusString:[self transportStatusString]};
}

- (NSString *)transportInfoString
{
	if (publishBonjourService)
	{
		NSString *name = bonjourServiceName;
		if ([name length])
		{
			return [NSString
					stringWithFormat:
					NSLocalizedString(@"Bonjour (%@, port %d%s)", @"Named Bonjour transport info string")
					,name
					,listenerPort
					,secure ? ", SSL" : ""];
		}
		
		return [NSString
				stringWithFormat:NSLocalizedString(@"Bonjour (port %d%s)", @"Bonjour transport (default name) info string")
				,listenerPort
				,secure ? ", SSL" : ""];
	}
	
	return [NSString
			stringWithFormat:NSLocalizedString(@"TCP/IP (port %d%s)", @"TCP/IP transport info string")
			,listenerPort
			,secure ? ", SSL" : ""];
}

- (NSString *)bonjourServiceName
{
	// returns the service name that we use when publishing over Bonjour
	return [[LoggerPreferenceManager sharedPrefManager] bonjourServiceName];
}

- (NSString *)bonjourServiceType
{
	// returns the Bonjour service type, depends on the exact type of service (encrypted or not)
	return (NSString *)(secure ? LOGGER_SERVICE_TYPE_SSL : LOGGER_SERVICE_TYPE);
}

- (NSInteger)tcpPort
{
	return [[LoggerPreferenceManager sharedPrefManager] directTCPIPResponderPort];
}

- (LoggerConnection *)connectionWithInputStream:(NSInputStream *)is clientAddress:(NSData *)addr
{
	return [[[LoggerTCPConnection alloc] initWithInputStream:is clientAddress:addr] autorelease];
}

- (void)processIncomingData:(LoggerTCPConnection *)cnx
{
	NSMutableArray *msgs = [[NSMutableArray alloc] init];

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
				// stkim1_Apr.07,2013
				// as soon as client info is recieved and client hash is generated,
				// then new connection gets reporeted to transport manager
				[cnx clientInfoReceived:message];
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
	{
		[cnx messagesReceived:msgs];
	}

	[msgs release];
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
		int i, b = sprintf(buffer," %04x: ", offset);
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
