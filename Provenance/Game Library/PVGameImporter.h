//
//  PVGameImporter.h
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PVGameImporterCompletionHandler)(BOOL encounteredConflicts);

@interface PVGameImporter : NSObject

@property (nonatomic, copy) PVGameImporterCompletionHandler completionHandler;

- (instancetype)initWithCompletionHandler:(PVGameImporterCompletionHandler)completionHandler;

- (void)startImport;

- (NSArray *)conflictedFiles;
- (void)resolveConflictsWithSolutions:(NSDictionary *)solutions;

@end
