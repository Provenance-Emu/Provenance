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
        if (self.completionHandler)
        {
            dispatch_async(dispatch_get_main_queue(), self.completionHandler);
        }
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
    
    // Look for CD-based ROMs first
    for (NSString *filePath in contents)
    {
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory])
        {
            if (isDirectory)
            {
                continue;
            }
            
            if ([self isCDROM:filePath])
            {
                [self moveCDROMToAppropriateSubfolder:filePath];
            }
        }
    }
    
    // After moving CD based ROMs, look for cartridge based ROMs
    contents = [fileManager contentsOfDirectoryAtPath:documentsDirectoryPath error:&error];
    
    if (!contents)
    {
        DLog(@"Error scanning %@, %@", documentsDirectoryPath, [error localizedDescription]);
        return;
    }

    for (NSString *filePath in contents)
    {
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory])
        {
            if (isDirectory)
            {
                continue;
            }
            
            [self moveROMToAppropriateSubfolder:filePath];
        }
    }
}

- (void)moveCDROMToAppropriateSubfolder:(NSString *)filePath
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
    
    // moved the .cue, or .iso or whatever, now move .bins .imgs etc
    
    NSString *relatedFileName = [filePath stringByReplacingOccurrencesOfString:[filePath pathExtension] withString:@""];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self documentsPath] error:&error];
    
    if (!contents)
    {
        DLog(@"Error scanning %@, %@", [self documentsPath], [error localizedDescription]);
        return;
    }
    
    for (NSString *file in contents)
    {
        NSString *fileWithoutExtension = [file stringByReplacingOccurrencesOfString:[file pathExtension] withString:@""];
        
        if ([fileWithoutExtension isEqual:relatedFileName])
        {
            if (![[NSFileManager defaultManager] moveItemAtPath:file toPath:subfolderPath error:&error])
            {
                DLog(@"Unable to move file from %@ to %@ - %@", filePath, subfolderPath, [error localizedDescription]);
            }
        }
    }
}

- (void)moveROMToAppropriateSubfolder:(NSString *)filePath
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

- (BOOL)isCDROM:(NSString *)filePath
{
    BOOL isCDROM = NO;
    
    PVEmulatorConfiguration *emuConfig = [PVEmulatorConfiguration sharedInstance];
    NSArray *cdExtensions = [emuConfig supportedCDFileExtensions];
    NSString *extension = [filePath pathExtension];
    if ([cdExtensions containsObject:extension])
    {
        isCDROM = YES;
    }
    
    return isCDROM;
}

@end
