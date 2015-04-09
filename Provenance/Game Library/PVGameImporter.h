//
//  PVGameImporter.h
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PVGameImporterCompletionHandler)(BOOL encounteredConflicts);
typedef void (^PVGameImporterFinishedImportingGameHandler)(NSString *md5Hash);
typedef void (^PVGameImporterFinishedGettingArtworkHandler)(NSString *artworkURL);

@interface PVGameImporter : NSObject

@property (nonatomic, copy) PVGameImporterCompletionHandler completionHandler;
@property (nonatomic, copy) PVGameImporterFinishedImportingGameHandler finishedImportHandler;
@property (nonatomic, copy) PVGameImporterFinishedGettingArtworkHandler finishedArtworkHandler;

- (instancetype)initWithCompletionHandler:(PVGameImporterCompletionHandler)completionHandler;

- (void)startImport;

- (NSArray *)conflictedFiles;
- (void)resolveConflictsWithSolutions:(NSDictionary *)solutions;

- (void)getArtworkFromURL:(NSString *)url;

@end
