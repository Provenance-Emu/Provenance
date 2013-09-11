//
//  PVDirectoryWatcher.h
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^PVDirectoryChangedHandler)(void);

@interface PVDirectoryWatcher : NSObject

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) PVDirectoryChangedHandler directoryChangedHandler;

- (id)initWithPath:(NSString *)path directoryChangedHandler:(PVDirectoryChangedHandler)handler;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
