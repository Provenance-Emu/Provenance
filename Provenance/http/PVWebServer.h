//
//  PVWebServer.h
//  Provenance
//
//  Created by Daniel Gillespie on 7/25/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

// Networking (GET IP)
#include <ifaddrs.h>
#include <arpa/inet.h>


@interface PVWebServer : NSObject

NS_ASSUME_NONNULL_BEGIN;

+ (instancetype)sharedInstance;

@property (nonatomic, retain, readonly) NSString *documentsDirectory;
@property (nonatomic, retain, readonly) NSString *IPAddress;
@property (nonatomic, retain, readonly) NSString *URLString;
@property (nonatomic, retain, readonly) NSString *WebDavURLString;
@property (nonatomic, retain, readonly) NSURL *URL;
@property (nonatomic, retain, readonly) NSURL *bonjourSeverURL;

- (BOOL)startServers;
- (void)stopServers;

- (BOOL)startWWWUploadServer;
- (void)stopWWWUploadServer;

- (BOOL)startWebDavServer;
- (void)stopWebDavServer;

NS_ASSUME_NONNULL_END;

@end
