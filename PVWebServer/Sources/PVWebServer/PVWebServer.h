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

// Notification names for file uploads
extern NSString* const PVWebServerFileUploadStartedNotification;
extern NSString* const PVWebServerFileUploadProgressNotification;
extern NSString* const PVWebServerFileUploadCompletedNotification;
extern NSString* const PVWebServerFileUploadFailedNotification;

NS_ASSUME_NONNULL_BEGIN;

@property (class, nonatomic, strong, readonly, nonnull) PVWebServer * sharedInstance NS_SWIFT_NAME(shared);

@property (nonatomic, strong, readonly, nullable) NSString *documentsDirectory;
@property (nonatomic, strong, readonly, nullable) NSString *appGroupDocumentsDirectory;
@property (nonatomic, strong, readonly, nullable) NSString *IPAddress;
@property (nonatomic, strong, readonly, nullable) NSString *URLString;
@property (nonatomic, strong, readonly, nullable) NSString *WebDavURLString;
@property (nonatomic, strong, readonly, nullable) NSURL *URL;
@property (nonatomic, strong, readonly, nullable) NSURL *bonjourSeverURL;

@property (nonatomic, assign, readonly) BOOL isWWWUploadServerRunning;
@property (nonatomic, assign, readonly) BOOL isWebDavServerRunning;

// Upload tracking properties
@property (nonatomic, strong, readonly) NSMutableArray *uploadQueue;
@property (nonatomic, assign, readonly) NSUInteger uploadQueueLength;
@property (nonatomic, strong, readonly, nullable) NSString *currentUploadingFilePath;
@property (nonatomic, assign, readonly) float currentUploadProgress;
@property (nonatomic, assign, readonly) uint64_t currentUploadFileSize;
@property (nonatomic, assign, readonly) uint64_t currentUploadBytesTransferred;

- (BOOL)startServers;
- (void)stopServers;

- (BOOL)startWWWUploadServer;
- (void)stopWWWUploadServer;

- (BOOL)startWebDavServer;
- (void)stopWebDavServer;

NS_ASSUME_NONNULL_END;

@end
