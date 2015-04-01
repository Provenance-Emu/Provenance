//
//  PVGameImporter.m
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVGameImporter.h"
#import "PVEmulatorConfiguration.h"

@interface PVGameImporter ()

@property (nonatomic, strong) dispatch_queue_t serialImportQueue;
@property (nonatomic, strong) NSDictionary *systemToPathMap;
@property (nonatomic, strong) NSDictionary *romToSystemMap;

@end

@implementation PVGameImporter

- (instancetype)init
{
    if ((self = [super init]))
    {
        self.serialImportQueue = dispatch_queue_create("com.jamsoftonline.provenance.serialImportQueue", DISPATCH_QUEUE_SERIAL);
        self.systemToPathMap = [self updateSystemToPathMap];
        self.romToSystemMap = [self updateRomToSystemMap];
    }
    
    return self;
}

- (void)dealloc
{
    self.serialImportQueue = nil;
}

- (void)enqueueScan
{
    dispatch_async(self.serialImportQueue, ^{
        [self scanForRoms];
    });
}

- (void)scanForRoms
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsDirectoryPath = [self documentsPath];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:documentsDirectoryPath error:&error];
    
    if (!contents)
    {
        DLog(@"Error scanning %@, %@", documentsDirectoryPath, [error localizedDescription]);
        return;
    }
    
    for (NSString *filePath in contents)
    {
        BOOL isDirectory = NO;
        [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
        
        if (isDirectory)
        {
            continue;
        }
        
        [self moveFileToAppropriateSubfolder:filePath];
    }
}

- (void)moveFileToAppropriateSubfolder:(NSString *)filePath
{
    NSArray *systemsForExtension = [self systemIDsForRomAtPath:filePath];
    
    NSString *systemID = nil;
    NSString *subfolderPath = nil;
    
    if ([systemsForExtension count] > 1)
    {
        subfolderPath = [self conflictPath];
    }
    else
    {
        systemID = [systemsForExtension firstObject];
        subfolderPath = self.systemToPathMap[systemID];
    }
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:subfolderPath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error])
    {
        DLog(@"Unable to create %@ - %@", subfolderPath, [error localizedDescription]);
        return;
    }
    
    if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:subfolderPath error:&error])
    {
        DLog(@"Unable to move file from %@ to %@ - %@", filePath, subfolderPath, [error localizedDescription]);
    }
}

#pragma mark - Utils

- (NSString *)documentsPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    return [paths firstObject];
}

- (NSString *)conflictPath
{
    return [[self documentsPath] stringByAppendingPathComponent:@"conflict"];
}

- (NSDictionary *)updateSystemToPathMap
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    PVEmulatorConfiguration *emuConfig = [PVEmulatorConfiguration sharedInstance];
    
    for (NSString *systemID in [emuConfig availableSystemIdentifiers])
    {
        NSString *path = [[self documentsPath] stringByAppendingPathComponent:systemID];
        map[systemID] = path;
    }
    
    return [map copy];
}

- (NSDictionary *)updateRomToSystemMap
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    PVEmulatorConfiguration *emuConfig = [PVEmulatorConfiguration sharedInstance];
    
    for (NSString *systemID in [emuConfig availableSystemIdentifiers])
    {
        for (NSString *fileExtension in [emuConfig fileExtensionsForSystemIdentifier:systemID])
        {
            NSMutableArray *systems = [map[fileExtension] mutableCopy];
            
            if (!systems)
            {
                systems = [NSMutableArray array];
            }
            
            [systems addObject:systemID];
            map[fileExtension] = [systems copy];
        }
    }
    
    return [map copy];
}

- (NSString *)pathForSystemID:(NSString *)systemID
{
    return self.systemToPathMap[systemID];
}

- (NSArray *)systemIDsForRomAtPath:(NSString *)path
{
    NSString *fileExtension = [[path pathExtension] lowercaseString];
    return self.romToSystemMap[fileExtension];
}

@end
