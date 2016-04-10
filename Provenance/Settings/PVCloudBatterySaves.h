//
//  PVCloudBatterySaves.h
//  CKTest
//
//  Created by Joshua Delman on 2/23/16.
//  Copyright © 2016 Pemdas. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CloudKit;

@interface PVCloudBatterySaves : NSObject

- (void)fetchAllRecordsWithCompletion:(void(^)(NSArray<CKRecord *>* records))completion;
- (void)createRecordForGame:(NSString *)gameName urlToSaveFile:(NSURL *)url completionBlock:(void(^)(BOOL success))completion;
- (void)updateRecordForGame:(NSString *)gameName urlToSaveFile:(NSURL *)url completionBlock:(void(^)(BOOL success))completion;

- (BOOL)cloudSaveExistsForGame:(NSString *)game;


@end
