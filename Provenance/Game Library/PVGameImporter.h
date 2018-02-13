//
//  PVGameImporter.h
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^PVGameImporterImportStartedHandler)(NSString *path);
typedef void (^PVGameImporterCompletionHandler)(BOOL encounteredConflicts);
typedef void (^PVGameImporterFinishedImportingGameHandler)(NSString *md5Hash, BOOL modified);
typedef void (^PVGameImporterFinishedGettingArtworkHandler)(NSString *artworkURL);
NS_ASSUME_NONNULL_END

@class PVGame;
@class OESQLiteDatabase;

@interface PVGameImporter : NSObject

@property (nonatomic, readonly, strong, nonnull) dispatch_queue_t serialImportQueue;

@property (nonatomic, copy, nullable) PVGameImporterImportStartedHandler importStartedHandler;
@property (nonatomic, copy, nullable) PVGameImporterCompletionHandler completionHandler;
@property (nonatomic, copy, nullable) PVGameImporterFinishedImportingGameHandler finishedImportHandler;
@property (nonatomic, copy, nullable) PVGameImporterFinishedGettingArtworkHandler finishedArtworkHandler;
@property (nonatomic, assign) BOOL encounteredConflicts;

- (instancetype _Nonnull )initWithCompletionHandler:(PVGameImporterCompletionHandler __nullable)completionHandler;

NS_ASSUME_NONNULL_BEGIN
- (void)startImportForPaths:(NSArray *)paths;

- (NSArray *)conflictedFiles;
- (void)resolveConflictsWithSolutions:(NSDictionary *)solutions;

//- (void)getRomInfoForFilesAtPaths:(NSArray *)paths userChosenSystem:(NSString *)systemID;
- (void)getArtworkFromURL:(NSString *)url;
NS_ASSUME_NONNULL_END

@end

// Private
@interface PVGameImporter()
- (NSString* _Nullable)calculateMD5ForGame:(PVGame *_Nonnull)game;
- (NSString * _Nonnull)documentsPath;
@property (nonatomic, strong) OESQLiteDatabase * _Nullable openVGDB;
@end
