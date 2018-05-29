/*
 *
 * Modified BSD license.
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


#import "SynthesizeSingleton.h"
#import "LoggerTransportManager.h"

#import "LoggerNativeLegacyTransport.h"
#import "LoggerConnection.h"

#import "LoggerPreferenceManager.h"
#import "LoggerDataManager.h"

static NSString * const kTransportNotificationKey = @"notiKey";
static NSString * const kTransportNotificationUserInfo = @"userInfo";

@interface LoggerTransportManager()
@property (nonatomic, retain, readwrite) LoggerCertManager *certificateStorage;
@property (nonatomic, retain) NSMutableArray	*transports;

- (void)createTransports;
- (void)destoryTransports;
- (void)startTransports;
- (void)stopTransports;
- (void)presentNotificationOnMainThread:(NSDictionary *)aNotiDict;
@end

@implementation LoggerTransportManager
{
	LoggerCertManager			*_certificateStorage;
	LoggerPreferenceManager		*_prefManager;
	NSMutableArray				*_transports;
	LoggerDataManager			*_dataManager;
}
@synthesize prefManager = _prefManager;
@synthesize certificateStorage = _certificateStorage;
@synthesize transports = _transports;
@synthesize dataManager = _dataManager;

SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(LoggerTransportManager,sharedTransportManager);

- (id)init
{
	self = [super init];
	if (self)
	{
		if(_certificateStorage == nil)
		{
			NSError *error = nil;
			LoggerCertManager *aCertManager = [[LoggerCertManager alloc] init];
			_certificateStorage = aCertManager;

			// we load server cert at this point to reduce any delay might happen
			// later in transport object.
			if(![aCertManager loadEncryptionCertificate:&error])
			{
				// @@@ TODO: do something when error is not nil;
				NSLog(@"Certification loading error. SSL connection will not be available.\n\n %@",error);
			}
		}
		
		if(_transports == nil)
		{
			_transports = [[NSMutableArray alloc] initWithCapacity:0];
		}
	}

    return self;
}

-(void)createTransports
{
	// unencrypted Bonjour service (for backwards compatibility)
	LoggerNativeLegacyTransport *t;

	// SSL Bonjour service
	t = [[LoggerNativeLegacyTransport alloc] init];
	t.publishBonjourService = YES;
	t.useBluetooth = YES;
	t.secure = YES;
	t.tag = 0;
	[self.transports addObject:t];
	[t release];
	
	// non-SSL bonjour Service
	t = [[LoggerNativeLegacyTransport alloc] init];
	t.publishBonjourService = YES;
	t.useBluetooth = YES;
	t.secure = NO;
	t.tag = 1;
	[self.transports addObject:t];
	[t release];

	// Direct TCP/IP service (SSL mandatory)
	t = [[LoggerNativeLegacyTransport alloc] init];
	t.listenerPort = [self.prefManager directTCPIPResponderPort];
	t.secure = YES;
	t.tag = 2;
	[self.transports addObject:t];
	[t release];
}

-(void)destoryTransports
{
	[self stopTransports];
	[self.transports removeAllObjects];
}

-(void)startTransports
{
	// Start and stop transports as needed
	for (LoggerNativeLegacyTransport *transport in self.transports)
	{
		if(!transport.active)
		{
			[transport restart];
		}
	}
}

-(void)stopTransports
{	
	// Start and stop transports as needed
	for (LoggerNativeLegacyTransport *transport in self.transports)
	{
		[transport shutdown];
	}
}

// -----------------------------------------------------------------------------
#pragma mark - AppDelegate Cycle Handle
// -----------------------------------------------------------------------------

-(void)appStarted
{
	[self createTransports];
}

-(void)appBecomeActive
{
	[self startTransports];
}

-(void)appResignActive
{
	[self stopTransports];
}

-(void)appWillTerminate
{
	[self destoryTransports];
}

// -----------------------------------------------------------------------------
#pragma mark - Handling Report from Transport
// -----------------------------------------------------------------------------
-(void)presentNotificationOnMainThread:(NSDictionary *)aNotiDict
{
	if([NSThread isMainThread])
	{
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:[aNotiDict valueForKey:kTransportNotificationKey]
		 object:self
		 userInfo:[aNotiDict valueForKey:kTransportNotificationUserInfo]];
	}
	else
	{
		[self
		 performSelectorOnMainThread:_cmd
		 withObject:aNotiDict
		 waitUntilDone:NO];
	}
}

-(void)presentTransportStatus:(NSDictionary *)aStatusDict
					   forKey:(NSString *)aKey
{
	[self
	 presentNotificationOnMainThread:
		 @{kTransportNotificationKey:aKey
		 ,kTransportNotificationUserInfo:aStatusDict}];
}

- (void)presentTransportStatus:(NSDictionary *)aStatusDict
{
	[self
	 presentNotificationOnMainThread:
		@{kTransportNotificationKey: kShowTransportStatusNotification
		,kTransportNotificationUserInfo:aStatusDict}];
}

- (void)presentTransportError:(NSDictionary *)anErrorDict
{
	[self
	 presentNotificationOnMainThread:
	 @{kTransportNotificationKey: kShowTransportErrorNotification
	 ,kTransportNotificationUserInfo:anErrorDict}];
}

// -----------------------------------------------------------------------------
#pragma mark - Logger Transport Delegate
// -----------------------------------------------------------------------------
// transport report new connection to manager
- (void)transport:(LoggerTransport *)theTransport
didEstablishConnection:(LoggerConnection *)theConnection
clientInfo:(LoggerMessage *)theInfoMessage
{
	// report transport status first
	[self presentTransportStatus:[theTransport status]];

	[_dataManager
	 transport:theTransport
	 didEstablishConnection:theConnection
	 clientInfo:theInfoMessage];
}

// method that may not be called on main thread
- (void)transport:(LoggerTransport *)theTransport
	   connection:(LoggerConnection *)theConnection
didReceiveMessages:(NSArray *)theMessages
			range:(NSRange)rangeInMessagesList
{
	[_dataManager
	 transport:theTransport
	 connection:theConnection
	 didReceiveMessages:theMessages
	 range:rangeInMessagesList];
}

- (void)transport:(LoggerTransport *)theTransport
didDisconnectRemote:(LoggerConnection *)theConnection
	  lastMessage:(LoggerMessage *)theLastMessage
{
	// report transport status first
	[self presentTransportStatus:[theTransport status]];

	[_dataManager
	 transport:theTransport
	 didDisconnectRemote:theConnection
	 lastMessage:theLastMessage];
}

- (void)transport:(LoggerTransport *)theTransport
 removeConnection:(LoggerConnection *)theConnection
{
	[_dataManager transport:theTransport removeConnection:theConnection];
}

@end
