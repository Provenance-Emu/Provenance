//
//  PVCloudBatterySaves.m
//  CKTest
//
//  Created by Joshua Delman on 2/23/16.
//  Copyright © 2016 Pemdas. All rights reserved.
//

#import "PVCloudBatterySaves.h"
@import UIKit;

@interface PVCloudBatterySaves ()
@property (strong, nonatomic) CKDatabase *userDB;
@property (strong, nonatomic) NSArray<CKRecord *> *localRecordDB;
@end

@implementation PVCloudBatterySaves

- (id)init {
    if (self = [super init]) {
        _userDB = [[CKContainer containerWithIdentifier:@"iCloud.com.pemdas.Provenance"] privateCloudDatabase];
    }
    
    return self;
}

- (void)fetchAllRecordsWithCompletion:(void(^)(NSArray<CKRecord *>* records))completion {
    NSLog(@"Fetching all records...");
    
    NSPredicate *fetchAllPredicate = [NSPredicate predicateWithValue:YES];
    CKQuery *fetchAllQuery = [[CKQuery alloc] initWithRecordType:@"BatterySave" predicate:fetchAllPredicate];
    [_userDB performQuery:fetchAllQuery inZoneWithID:nil completionHandler:^(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error) {
       
        if (error) {
            NSLog(@"Error fetching all records: %@", error);
            if (completion) {
                completion(nil);
            }
        }
        
        if (!results) {
            _localRecordDB = @[];
        }
        else {
            _localRecordDB = [results copy];
        }
        
//        [results enumerateObjectsUsingBlock:^(CKRecord * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//            
//            NSLog(@"found record: %@", obj);
//            
//        }];
        
        if (completion) {
            completion(results);
        }
        
    }];
}

- (void)createRecordForGame:(NSString *)gameName urlToSaveFile:(NSURL *)url completionBlock:(void(^)(BOOL success))completion {
    CKRecord *newRecord = [[CKRecord alloc] initWithRecordType:@"BatterySave"];
    [newRecord setObject:gameName forKey:@"game"];
    
    // create CKAsset with save
    CKAsset *gameSave = [[CKAsset alloc] initWithFileURL:url];
    [newRecord setObject:gameSave forKey:@"saveBinary"];
    
    // set dateSave to the fileModificationDate of the save
    [newRecord setObject:[self lastModifiedDateOfFileAtUrl:url] forKey:@"dateSave"];
    
    // get the fileExtension
    NSString *fileExtension = [[[[url absoluteString] lastPathComponent] componentsSeparatedByString:@"."] lastObject];
    [newRecord setObject:fileExtension forKey:@"fileExtension"];
    
    // save the device
    NSString *deviceStr = [NSString stringWithFormat:@"%@ (%@)", [UIDevice currentDevice].name, [UIDevice currentDevice].model];
    [newRecord setObject:deviceStr forKey:@"device"];
    
    [_userDB saveRecord:newRecord completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
        if (completion && !error) {
            NSLog(@"Successfully saved record: %@", record);
            completion(YES);
        }
        else if (completion && error) {
            NSLog(@"Failed to save record: %@: %@", newRecord, error);
            completion(NO);
        }
    }];

}

- (void)updateRecordForGame:(NSString *)gameName urlToSaveFile:(NSURL *)url completionBlock:(void(^)(BOOL success))completion {
    
    // use the local records DB to get the recordID
    CKRecordID *gameRecordID;
    for (CKRecord *record in _localRecordDB) {
        NSString *gName = [record objectForKey:@"game"];
        if ([gName isEqualToString:gameName]) {
            gameRecordID = record.recordID;
            break;
        }
    }
    
    if (!gameRecordID) {
        NSLog(@"Could not find a record for: %@", gameName);
        if (completion) {
            completion(NO);
        }
    }
    
    // fetch the record and update it
    [_userDB fetchRecordWithID:gameRecordID completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
       
        if (error) {
            NSLog(@"error fetching record with ID: %@ - %@", gameRecordID, error);
            if (completion) {
                completion(NO);
            }
            return;
        }
        
        // set the asset
        CKAsset *gameSaveBinary = [[CKAsset alloc] initWithFileURL:url];
        [record setObject:gameSaveBinary forKey:@"saveBinary"];
        
        // set the dateSave
        [record setObject:[self lastModifiedDateOfFileAtUrl:url] forKey:@"dateSave"];
        
        // update device
        NSString *deviceStr = [NSString stringWithFormat:@"%@ (%@)", [UIDevice currentDevice].name, [UIDevice currentDevice].model];
        [record setObject:deviceStr forKey:@"device"];
        
        // now, perform an update query.
        CKModifyRecordsOperation *op = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[record] recordIDsToDelete:nil];
        op.modifyRecordsCompletionBlock = ^(NSArray *savedRecords, NSArray *deletedRecordIDs, NSError *error) {
            if (error) {
                NSLog(@"error updating record for: %@ - %@", gameName, error);
                if (completion) {
                    completion(NO);
                    return;
                }
            }
            
            NSLog(@"Successfully updated record for game: %@", gameName);
            
            if (completion) {
                completion(YES);
            }

        };
        
        [_userDB addOperation:op];
    }];
    
}

- (void)fetchRecordForGame:(NSString *)gameName completionBlock:(void(^)(NSURL *urlOfSaveBinary))completion {
    NSPredicate *fetchGamePredicate = [NSPredicate predicateWithFormat:@"game == %@", gameName];
    CKQuery *fetchGameQuery = [[CKQuery alloc] initWithRecordType:@"BatterySave" predicate:fetchGamePredicate];
    [_userDB performQuery:fetchGameQuery inZoneWithID:nil completionHandler:^(NSArray<CKRecord *> * _Nullable results, NSError * _Nullable error) {
        // there should just be one record...
        if ([results count] > 0) {
            CKRecord *gameRecord = [results firstObject];
            if (completion) {
                CKAsset *saveBinary = [gameRecord objectForKey:@"saveBinary"];
                completion(saveBinary.fileURL);
            }
        }
    }];
}

- (BOOL)cloudSaveExistsForGame:(NSString *)game {
    for (NSDictionary *dict in _localRecordDB) {
        if ([[dict objectForKey:@"game"] isEqualToString:game]) {
            return YES;
        }
    }
    return NO;
}

- (NSDate *)lastModifiedDateOfFileAtUrl:(NSURL *)url {
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:&error];
    
    if (error) {
        NSLog(@"error retrieving last modified date: %@", error);
        return nil;
    }
    
    return [attributes fileModificationDate];
}

@end
