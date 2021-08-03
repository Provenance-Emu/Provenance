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

@property (class, nonatomic, strong, readonly, nonnull) PVWebServer * sharedInstance NS_SWIFT_NAME(shared);

@property (nonatomic, strong, readonly) NSString *documentsDirectory;
@property (nonatomic, strong, readonly) NSString *IPAddress;
@property (nonatomic, strong, readonly) NSString *URLString;
@property (nonatomic, strong, readonly) NSString *WebDavURLString;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) NSURL *bonjourSeverURL;

@property (nonatomic, assign, readonly) BOOL isWWWUploadServerRunning;
@property (nonatomic, assign, readonly) BOOL isWebDavServerRunning;

- (BOOL)startServers;
- (void)stopServers;

- (BOOL)startWWWUploadServer;
- (void)stopWWWUploadServer;

- (BOOL)startWebDavServer;
- (void)stopWebDavServer;

NS_ASSUME_NONNULL_END;

@end
