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

// Web Server
#import "GCDWebUploader.h"

@interface PVWebServer : NSObject <GCDWebUploaderDelegate>

+ (PVWebServer *)sharedInstance;

- (NSString *)getDocumentDirectory;
- (NSString *)getIPAddress;
- (NSString *)getURLString;
- (NSURL *)getURL;
- (NSURL *)bonjourServerURL;
- (void)startServer;
- (void)stopServer;


@end
