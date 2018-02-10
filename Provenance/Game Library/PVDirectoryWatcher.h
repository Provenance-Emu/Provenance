//
//  PVDirectoryWatcher.h
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * __nonnull PVArchiveInflationFailedNotification;

typedef void(^PVExtractionStartedHandler)(NSString *__nonnull path);
typedef void(^PVExtractionUpdatedHandler)(NSString *__nonnull path, NSInteger entryNumber, NSInteger total, float progress);
typedef void(^PVExtractionCompleteHandler)(NSArray<NSString *> *__nonnull paths);

@interface PVDirectoryWatcher : NSObject

@property (nonatomic, readonly, nonnull) NSString *path;
@property (nonatomic, readonly, copy, nullable) PVExtractionStartedHandler extractionStartedHandler;
@property (nonatomic, readonly, copy, nullable) PVExtractionUpdatedHandler extractionUpdatedHandler;
@property (nonatomic, readonly, copy, nullable) PVExtractionCompleteHandler extractionCompleteHandler;

- (instancetype _Nonnull)initWithPath:(NSString * _Nonnull)path extractionStartedHandler:(PVExtractionStartedHandler _Nullable)startedHandler extractionUpdatedHandler:(PVExtractionUpdatedHandler _Nullable)updatedHandler extractionCompleteHandler:(PVExtractionCompleteHandler _Nullable)completeHandler;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
