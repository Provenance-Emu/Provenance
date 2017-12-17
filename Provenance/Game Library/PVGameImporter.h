//
//  PVGameImporter.h
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PVGameImporterImportStartedHandler)(NSString *path);
typedef void (^PVGameImporterCompletionHandler)(BOOL encounteredConflicts);
typedef void (^PVGameImporterFinishedImportingGameHandler)(NSString *md5Hash, BOOL modified);
typedef void (^PVGameImporterFinishedGettingArtworkHandler)(NSString *artworkURL);

@class PVGame;

@interface PVGameImporter : NSObject

@property (nonatomic, readonly, strong) dispatch_queue_t serialImportQueue;

@property (nonatomic, copy) PVGameImporterImportStartedHandler importStartedHandler;
@property (nonatomic, copy) PVGameImporterCompletionHandler completionHandler;
@property (nonatomic, copy) PVGameImporterFinishedImportingGameHandler finishedImportHandler;
@property (nonatomic, copy) PVGameImporterFinishedGettingArtworkHandler finishedArtworkHandler;
@property (nonatomic, assign) BOOL encounteredConflicts;

- (instancetype)initWithCompletionHandler:(PVGameImporterCompletionHandler)completionHandler;

- (void)startImportForPaths:(NSArray *)paths;

- (NSArray *)conflictedFiles;
- (void)resolveConflictsWithSolutions:(NSDictionary *)solutions;

- (void)getRomInfoForFilesAtPaths:(NSArray *)paths userChosenSystem:(NSString *)systemID;
- (void)getArtworkFromURL:(NSString *)url;

/**
 Import a specifically named image file to the matching game.
 
 To update “Kart Fighter.nes”, use an image named “Kart Fighter.nes.png”.

 @param imageFullPath The artwork image path
 @return The game that was updated
 */
+ (PVGame *)importArtworkFromPath:(NSString *)imageFullPath;

@end

@interface PVGameImporter (Private)
- (NSString *)documentsPath;
@end
