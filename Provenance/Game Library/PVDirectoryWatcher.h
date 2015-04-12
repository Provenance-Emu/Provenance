//
//  PVDirectoryWatcher.h
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *PVArchiveInflationFailedNotification;

typedef void(^PVExtractionCompleteHandler)(NSArray *paths);

@interface PVDirectoryWatcher : NSObject

@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly, copy) PVExtractionCompleteHandler extractionCompleteHandler;

- (id)initWithPath:(NSString *)path extractionCompleteHandler:(PVExtractionCompleteHandler)handler;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
