//
//  PVDirectoryWatcher.h
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *PVArchiveInflationFailedNotification;

typedef void(^PVExtractionStartedHandler)(NSString *path);
typedef void(^PVExtractionUpdatedHandler)(NSString *path, NSInteger entryNumber, NSInteger total, float progress);
typedef void(^PVExtractionCompleteHandler)(NSArray *paths);

@interface PVDirectoryWatcher : NSObject

@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) PVExtractionStartedHandler extractionStartedHandler;
@property (nonatomic, readonly, copy) PVExtractionUpdatedHandler extractionUpdatedHandler;
@property (nonatomic, readonly, copy) PVExtractionCompleteHandler extractionCompleteHandler;

- (id)initWithPath:(NSString *)path extractionStartedHandler:(PVExtractionStartedHandler)startedHandler extractionUpdatedHandler:(PVExtractionUpdatedHandler)updatedHandler extractionCompleteHandler:(PVExtractionCompleteHandler)completeHandler;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
