//
//  PVGameImporter.m
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVGameImporter.h"
#import "PVEmulatorConfiguration.h"
#import "PVGame.h"
#import "OESQLiteDatabase.h"
#import "NSFileManager+Hashing.h"
#import "PVMediaCache.h"
#import <Realm/Realm.h>
#import "PVSynchronousURLSession.h"
#import "PVEmulatorConstants.h"
#import "PVAppConstants.h"
#import "UIImage+Scaling.h"
#import "NSData+Hashing.h"


@interface NSArray (Map)

- (NSArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block;

@end

@implementation NSArray (Map)

- (NSArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:block(obj, idx)];
    }];
    return result;
}

@end

@interface ImportCanidateFile : NSObject
@property (nonatomic, strong, nonnull) NSString *filePath;
@property (nonatomic, strong, nonnull) NSString *md5;

- (instancetype)initWithFilePath:(NSString* _Nonnull)filePath;
@end


@implementation ImportCanidateFile {
    NSString * _hastStore;
    dispatch_once_t _hashToken;
    
}

- (instancetype)initWithFilePath:(NSString* _Nonnull)filePath
{
    self = [super init];
    if (self) {
        _filePath = filePath;
    }
    return self;
}

-(NSString* _Nonnull)md5 {
    dispatch_once(&_hashToken, ^{
        if (_hastStore == nil) {
            NSFileManager *fm = [NSFileManager defaultManager];
            _hastStore = [fm MD5ForFileAtPath:_filePath fromOffset:0];
        }
    });
    
    return _hastStore;
}

@end

@interface PVGameImporter ()

@property (nonatomic, readwrite, strong) dispatch_queue_t serialImportQueue;
@property (nonatomic, strong) NSDictionary *systemToPathMap;
@property (nonatomic, strong) NSDictionary *romToSystemMap;
@property (nonatomic, strong) OESQLiteDatabase *openVGDB;

@end

@implementation PVGameImporter

- (instancetype)initWithCompletionHandler:(PVGameImporterCompletionHandler)completionHandler
{
    if ((self = [self init]))
    {
        _completionHandler = completionHandler;
    }
    
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _serialImportQueue = dispatch_queue_create("com.jamsoftonline.provenance.serialImportQueue", DISPATCH_QUEUE_SERIAL);
        _systemToPathMap   = [self updateSystemToPathMap];
        _romToSystemMap    = [self updateRomToSystemMap];
    }
    return self;
}

- (void)startImportForPaths:(NSArray<NSString*> *)paths
{
    dispatch_async(self.serialImportQueue, ^{
        NSArray *newPaths = [self importFilesAtPaths:paths];
        [self getRomInfoForFilesAtPaths:newPaths userChosenSystem:nil];
        if (self.completionHandler)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.completionHandler(self.encounteredConflicts);
            });
        }
    });
}

- (NSArray<NSString*> *)importFilesAtPaths:(NSArray<NSString*> *)paths
{
    NSMutableArray<NSString*> *newPaths = [NSMutableArray array];
    
    // Reorder .cue's first.this is so we find cue's before their bins.
    paths = [paths sortedArrayUsingComparator:^NSComparisonResult(NSString*  _Nonnull obj1, NSString*  _Nonnull obj2) {
        if ([obj1.pathExtension isEqualToString:@"cue"]) {
            return NSOrderedAscending;
        } else if ([obj2.pathExtension isEqualToString:@"cue"]) {
            return NSOrderedDescending;
        } else {
            return [obj1 compare:obj2];
        }
    }];
    
    NSArray<ImportCanidateFile*> *canidateFiles = [paths mapObjectsUsingBlock:^ImportCanidateFile*(NSString* path, NSUInteger idx) {
        return [[ImportCanidateFile alloc] initWithFilePath:[[self romsPath] stringByAppendingPathComponent:path]];
    }];

    // do CDs first to avoid the case where an item related to CDs is mistaken as another rom and moved
    // before processing its CD cue sheet or something
    for (ImportCanidateFile *canidate in canidateFiles)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:canidate.filePath])
        {
            if ([self isCDROM:canidate])
            {
                [newPaths addObjectsFromArray:[self moveCDROMToAppropriateSubfolder:canidate]];
            }
        }
    }
    
    for (ImportCanidateFile *canidate in canidateFiles)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:canidate.filePath])
        {
            NSString *newPath = [self moveROMToAppropriateSubfolder:canidate];
            if ([newPath length])
            {
                [newPaths addObject:newPath];
            }
        }
    }
    
    return newPaths;
}

-(OESQLiteDatabase*)openVGDB {
    if (_openVGDB == nil) {
        NSError *error;
        _openVGDB = [[OESQLiteDatabase alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"openvgdb" withExtension:@"sqlite"]
                                        error:&error];
        
        if (_openVGDB == nil) {
            DLog(@"Unable to open game database: %@", [error localizedDescription]);
            return nil;
        }
    }

    return _openVGDB;
}

-(NSString*)systemIdForROMCanidate:(ImportCanidateFile*)rom {
    
    NSString*md5 = rom.md5;
    NSString*fileName = rom.filePath.lastPathComponent;
    
    NSError*error;
    NSArray<NSDictionary<NSString*,NSObject*>*> *results = nil;
    NSString *queryString = [NSString stringWithFormat:@"SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '%@' OR romFileName = '%@'", md5, fileName];
    
    results = [self.openVGDB executeQuery:queryString
                                    error:&error];
    
    if (!results) {
        DLog(@"Unable to find rom by MD5: %@", error.localizedDescription);
    }
    
    if (results.count) {
        NSString *databaseID = results[0][@"systemID"].description;
        PVEmulatorConfiguration *config = [PVEmulatorConfiguration sharedInstance];
        NSString *systemID = [config systemIDForDatabaseID:databaseID];
        
        return systemID;
    } else {
        return nil;
    }
}

- (NSArray *)moveCDROMToAppropriateSubfolder:(ImportCanidateFile *)canidateFile
{
    NSMutableArray *newPaths = [NSMutableArray array];
    
    NSArray *systemsForExtension = [self systemIDsForRomAtPath:canidateFile.filePath];
    
    NSString *systemID = nil;
    NSString *subfolderPath = nil;
    
    if ([systemsForExtension count] > 1)
    {
        // Try to match by MD5 or filename
        NSString*systemID = [self systemIdForROMCanidate:canidateFile];
        
        if (systemID != nil) {
            subfolderPath = self.systemToPathMap[systemID];
        }
        else {
            // No MD5 match, so move to conflict dir
            subfolderPath = [self conflictPath];
            self.encounteredConflicts = YES;
        }
    }
    else
    {
        systemID = [systemsForExtension firstObject];
        subfolderPath = self.systemToPathMap[systemID];
    }
    
    if (![subfolderPath length])
    {
        return nil;
    }
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:subfolderPath
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error])
    {
        DLog(@"Unable to create %@ - %@", subfolderPath, [error localizedDescription]);
        return nil;
    }
    
    if (![[NSFileManager defaultManager] moveItemAtPath:[[self romsPath] stringByAppendingPathComponent:canidateFile.filePath.lastPathComponent]
                                                 toPath:[subfolderPath stringByAppendingPathComponent:canidateFile.filePath.lastPathComponent]
                                                  error:&error])
    {
        DLog(@"Unable to move file from %@ to %@ - %@", canidateFile, subfolderPath, [error localizedDescription]);
        return nil;
    }
    
    NSString *cueSheetPath = [subfolderPath stringByAppendingPathComponent:canidateFile.filePath];
    if (!self.encounteredConflicts)
    {
        [newPaths addObject:cueSheetPath];
    }
    
    // moved the .cue, now move .bins .imgs etc
    [self moveFilesSimiliarToFilename:canidateFile.filePath.lastPathComponent
                        fromDirectory:[self romsPath]
                          toDirectory:subfolderPath
                             cuesheet:cueSheetPath];
    
    return [newPaths copy];
}

-(void)moveFilesSimiliarToFilename:(NSString* _Nonnull)filename fromDirectory:(NSString* _Nonnull)from toDirectory:(NSString* _Nonnull)to cuesheet:(NSString*)cueSheetPath{
    NSError*error;
    NSString *relatedFileName = [filename stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@",[filename pathExtension]] withString:@""];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self romsPath] error:&error];
    
    if (!contents)
    {
        DLog(@"Error scanning %@, %@", [self romsPath], [error localizedDescription]);
        return;
    }
    
    for (NSString *file in contents)
    {
        NSString *fileWithoutExtension = [file stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@",[file pathExtension]] withString:@""];
        
        // Some cue's have multiple bins, like, Game.cue Game (Track 1).bin, Game (Track 2).bin ....
        // Clip down the file name to the length of the .cue to see if they start to match
        if (fileWithoutExtension.length > relatedFileName.length) {
            fileWithoutExtension = [fileWithoutExtension substringWithRange:NSMakeRange(0, relatedFileName.length)];
        }
        
        if ([fileWithoutExtension isEqual:relatedFileName])
        {
            // Before moving the file, make sure the cue sheet's reference uses the same case.
            if (cueSheetPath) {
                NSMutableString *cuesheet = [NSMutableString stringWithContentsOfFile:cueSheetPath encoding:NSUTF8StringEncoding error:&error];
                if (cuesheet)
                {
                    NSRange range = [cuesheet rangeOfString:file options:NSCaseInsensitiveSearch];
                    [cuesheet replaceCharactersInRange:range withString:file];
                    if (![cuesheet writeToFile:cueSheetPath
                                    atomically:NO
                                      encoding:NSUTF8StringEncoding
                                         error:&error])
                    {
                        DLog(@"Unable to rewrite cuesheet %@ because %@", cueSheetPath, [error localizedDescription]);
                    }
                }
                else
                {
                    DLog(@"Unable to read cue sheet %@ because %@", cueSheetPath, [error localizedDescription]);
                }
            }
            
            if (![[NSFileManager defaultManager] moveItemAtPath:[[self romsPath] stringByAppendingPathComponent:file] toPath:[to stringByAppendingPathComponent:file] error:&error])
            {
                DLog(@"Unable to move file from %@ to %@ - %@", filename, to, [error localizedDescription]);
            } else {
                DLog(@"Moved file from %@ to %@", filename, to);
            }
        }
    }
}

- (BIOSEntry*)moveIfBIOS:(ImportCanidateFile*)canidateFile {
    PVEmulatorConfiguration *config = [PVEmulatorConfiguration sharedInstance];
   
    BIOSEntry *bios;
    
    // Check if BIOS by filename - should possibly just only check MD5?
    if ((bios = [config biosEntryForFilename:canidateFile.filePath.lastPathComponent])) {
        return bios;
    } else {
        // Now check by MD5
        NSString *fileMD5 = canidateFile.md5;
        if ((bios = [config biosEntryForMD5:fileMD5])) {
            return bios;
        }
    }
    
    return nil;
}

- (NSString *)moveROMToAppropriateSubfolder:(ImportCanidateFile*)canidateFile
{
    NSString *filePath = canidateFile.filePath;
    NSString *newPath = nil;
    
    NSArray *systemsForExtension = [self systemIDsForRomAtPath:filePath];
    
    NSString *systemID = nil;
    NSString *subfolderPath = nil;
    
    NSFileManager*fm = [NSFileManager defaultManager];
    
    // Check first if known BIOS
    BIOSEntry *biosEntry = [self moveIfBIOS:canidateFile];
    if (biosEntry) {

        PVEmulatorConfiguration*config = [PVEmulatorConfiguration sharedInstance];
        NSString *biosDirectory = [config BIOSPathForSystemID:biosEntry.systemID];
        NSString *destiaionPath = [biosDirectory stringByAppendingPathComponent:biosEntry.filename];
        
        NSError *error = nil;
        
        if (![fm fileExistsAtPath:biosDirectory]) {
            [fm createDirectoryAtPath:biosDirectory
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            
            if (error) {
                DLog(@"Unable to create BIOS directory %@, %@", biosDirectory, error.localizedDescription);
            }
        }
        
        if (![fm moveItemAtPath:filePath
                         toPath:destiaionPath
                          error:&error])
        {
            if ([error code] == NSFileWriteFileExistsError)
            {
                DLog(@"Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, [error localizedDescription]);
            }
        }
        return nil;
    }
    
    if ([systemsForExtension count] > 1)
    {
        
        // Check by MD5
        NSString *fileMD5 = canidateFile.md5.uppercaseString;
        NSArray *results;
        for (NSString *system in systemsForExtension) {
            NSError* error;
            // TODO: Would be better performance to search EVERY system MD5 in a single query?
            results = [self searchDatabaseUsingKey:@"romHashMD5"
                                             value:fileMD5
                                          systemID:system
                                             error:&error];
            break;
        }
        
        if (results.count) {
            NSDictionary *chosenResult = nil;
            for (NSDictionary *result in results)
            {
                if ([result[@"region"] isEqualToString:@"USA"])
                {
                    chosenResult = result;
                    break;
                }
            }
            
            if (!chosenResult)
            {
                chosenResult = [results firstObject];
            }
            
            
        }
        
        subfolderPath = [self conflictPath];
        self.encounteredConflicts = YES;
    }
    else
    {
        systemID = [systemsForExtension firstObject];
        subfolderPath = self.systemToPathMap[systemID];
    }
    
    if (![subfolderPath length])
    {
        return nil;
    }
    
    NSError *error = nil;
    if (![fm createDirectoryAtPath:subfolderPath
       withIntermediateDirectories:YES
                        attributes:nil
                             error:&error])
    {
        DLog(@"Unable to create %@ - %@", subfolderPath, [error localizedDescription]);
        return nil;
    }
    
    if (![fm moveItemAtPath:filePath toPath:[subfolderPath stringByAppendingPathComponent:filePath.lastPathComponent] error:&error])
    {
        
        if ([error code] == NSFileWriteFileExistsError)
        {
            if (![fm removeItemAtPath:filePath error:&error])
            {
                DLog(@"Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, [error localizedDescription]);
            }
        }
        
        DLog(@"Unable to move file from %@ to %@ - %@", filePath, subfolderPath, [error localizedDescription]);
        return nil;
    }
    
    if (!self.encounteredConflicts)
    {
      newPath = [subfolderPath stringByAppendingPathComponent:filePath.lastPathComponent];
    }
    
    return newPath;
}

- (NSArray *)conflictedFiles
{
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self conflictPath] error:&error];
    if (!contents)
    {
        DLog(@"Unable to get contents of %@ because %@", [self conflictPath], [error localizedDescription]);
    }
    
    return contents;
}

- (void)resolveConflictsWithSolutions:(NSDictionary *)solutions
{
    NSArray *filePaths = [solutions allKeys];
    for (NSString *filePath in filePaths)
    {
        NSString *systemID = solutions[filePath];
        NSString *subfolder = self.systemToPathMap[systemID];
        if (![[NSFileManager defaultManager] fileExistsAtPath:subfolder])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:subfolder withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        NSError *error = nil;
        if (![[NSFileManager defaultManager] moveItemAtPath:[[self conflictPath] stringByAppendingPathComponent:filePath] toPath:[subfolder stringByAppendingPathComponent:filePath] error:&error])
        {
            DLog(@"Unable to move %@ to %@ because %@", filePath, subfolder, [error localizedDescription]);
        }
        
        // moved the .cue, now move .bins .imgs etc
        NSString *cueSheetPath = [subfolder stringByAppendingPathComponent:filePath];
        NSString *relatedFileName = filePath.stringByDeletingPathExtension;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self conflictPath] error:&error];
        
        for (NSString *file in contents)
        {
            // Crop out any extra info in the .bin files, like Game.cue and Game (Track 1).bin, we want to match up to just 'Game'
            NSString *fileWithoutExtension = [file stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", [file pathExtension]] withString:@""];
            if (fileWithoutExtension.length > relatedFileName.length) {
                fileWithoutExtension = [fileWithoutExtension substringWithRange:NSMakeRange(0, relatedFileName.length)];
            }
            
            if ([fileWithoutExtension isEqual:relatedFileName])
            {
                // Before moving the file, make sure the cue sheet's reference uses the same case.
                NSMutableString *cuesheet = [NSMutableString stringWithContentsOfFile:cueSheetPath encoding:NSUTF8StringEncoding error:&error];
                if (cuesheet)
                {
                    NSRange range = [cuesheet rangeOfString:file options:NSCaseInsensitiveSearch];
                    if (range.location != NSNotFound) {
                        [cuesheet replaceCharactersInRange:range withString:file];
                        if (![cuesheet writeToFile:cueSheetPath
                                        atomically:NO
                                          encoding:NSUTF8StringEncoding
                                             error:&error])
                        {
                            DLog(@"Unable to rewrite cuesheet %@ because %@", cueSheetPath, [error localizedDescription]);
                        }
                    } else {
                        DLog(@"Range of string <%@> not found in file <%@>", file, cueSheetPath);
                    }
                }
                else
                {
                    DLog(@"Unable to read cue sheet %@ because %@", cueSheetPath, [error localizedDescription]);
                }
                
                if (![[NSFileManager defaultManager] moveItemAtPath:[[self conflictPath] stringByAppendingPathComponent:file] toPath:[subfolder stringByAppendingPathComponent:file] error:&error])
                {
                    DLog(@"Unable to move file from %@ to %@ - %@", filePath, subfolder, [error localizedDescription]);
                }
            }
        }
        
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.serialImportQueue, ^{
            [weakSelf getRomInfoForFilesAtPaths:@[filePath] userChosenSystem:systemID];
            if (weakSelf.completionHandler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.completionHandler(NO);
                });
            }
        });
    }
}

#pragma mark - ROM Lookup

- (void)getRomInfoForFilesAtPaths:(NSArray *)paths userChosenSystem:(NSString *)chosenSystemID
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm refresh];
    for (NSString *path in paths)
    {
        if ([path hasPrefix:@"."])
        {
            continue;
        }
        
        @autoreleasepool {
            NSString *systemID = nil;
            if (![chosenSystemID length])
            {
                systemID = [[PVEmulatorConfiguration sharedInstance] systemIdentifierForFileExtension:[path pathExtension]];
            }
            else
            {
                systemID = chosenSystemID;
            }

            NSArray * cdBasedSystems = [[PVEmulatorConfiguration sharedInstance] cdBasedSystemIDs];
            if ([cdBasedSystems containsObject:systemID] &&
                ([[path pathExtension] isEqualToString:@"cue"] == NO))
            {
                continue;
            }

            NSString *partialPath = [systemID stringByAppendingPathComponent:[path lastPathComponent]];
            NSString *title = [[path lastPathComponent] stringByReplacingOccurrencesOfString:[@"." stringByAppendingString:[path pathExtension]] withString:@""];
            PVGame *game = nil;

            RLMResults *results = [PVGame objectsInRealm:realm withPredicate:[NSPredicate predicateWithFormat:@"romPath == %@", ([partialPath length]) ? partialPath : @""]];
            if ([results count])
            {
                game = [results firstObject];
            }
            else
            {
                if (![systemID length])
                {
                    continue;
                }

                game = [[PVGame alloc] init];
                [game setRomPath:partialPath];
                [game setTitle:title];
                [game setSystemIdentifier:systemID];
                [game setRequiresSync:YES];
                [realm beginWriteTransaction];
                [realm addObject:game];
                [realm commitWriteTransaction];
            }

            BOOL modified = NO;
            if ([game requiresSync])
            {
                if (self.importStartedHandler)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.importStartedHandler(path);
                    });
                }
                
                [self lookupInfoForGame:game];
                modified = YES;
            }
            
            if (self.finishedImportHandler)
            {
                NSString *md5 = [game md5Hash];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.finishedImportHandler(md5, modified);
                });
            }
            
            [self getArtworkFromURL:[game originalArtworkURL]];
        }
    }
}

- (void)lookupInfoForGame:(PVGame *)game
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm refresh];
    
    if (![[game md5Hash] length])
    {
        NSUInteger offset = 0;
        
        if ([[game systemIdentifier] isEqualToString:PVNESSystemIdentifier])
        {
            offset = 16; // make this better
        }
        
        NSString *md5Hash = [[NSFileManager defaultManager] MD5ForFileAtPath:[[self documentsPath] stringByAppendingPathComponent:[game romPath]]
                                                                   fromOffset:offset];
        
        [realm beginWriteTransaction];
        [game setMd5Hash:md5Hash];
        [realm commitWriteTransaction];
    }
    
    NSError *error = nil;
    NSArray *results = nil;
    
    if ([[game md5Hash] length])
    {
        results = [self searchDatabaseUsingKey:@"romHashMD5"
                                         value:[[game md5Hash] uppercaseString]
                                      systemID:[game systemIdentifier]
                                         error:&error];
    }
    
    if (![results count])
    {
        NSString *fileName = [[game romPath] lastPathComponent];
        
        // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
        static NSMutableCharacterSet *charSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            charSet = [NSMutableCharacterSet punctuationCharacterSet];
            [charSet removeCharactersInString:@"-+&.'"];
        });
        
        NSRange nonCharRange = [fileName rangeOfCharacterFromSet:charSet];
        NSUInteger gameTitleLen;
        if (nonCharRange.length > 0 && nonCharRange.location > 1) {
            gameTitleLen = nonCharRange.location - 1;
        } else {
            gameTitleLen = [fileName length];
        }
        fileName = [fileName substringToIndex:gameTitleLen];
        results = [self searchDatabaseUsingKey:@"romFileName"
                                         value:fileName
                                      systemID:[game systemIdentifier]
                                         error:&error];
    }
    
    if (![results count])
    {
        DLog(@"Unable to find ROM (%@) in DB", [game romPath]);
        [realm beginWriteTransaction];
        [game setRequiresSync:NO];
        [realm commitWriteTransaction];
        
        return;
    }
    
    NSDictionary *chosenResult = nil;
    for (NSDictionary *result in results)
    {
        if ([result[@"region"] isEqualToString:@"USA"])
        {
            chosenResult = result;
            break;
        }
    }
    
    if (!chosenResult)
    {
        chosenResult = [results firstObject];
    }
    
    [realm beginWriteTransaction];
    [game setRequiresSync:NO];
    if ([chosenResult[@"gameTitle"] length])
    {
        [game setTitle:chosenResult[@"gameTitle"]];
    }
    if ([chosenResult[@"boxImageURL"] length])
    {
        [game setOriginalArtworkURL:chosenResult[@"boxImageURL"]];
    }
    [realm commitWriteTransaction];
}

- (void)getArtworkFromURL:(NSString *)url
{
    if (![url length] || [[PVMediaCache filePathForKey:url] length])
    {
        return;
    }
    
    DLog(@"Starting Artwork download for %@", url);
    NSURL *artworkURL = [NSURL URLWithString:url];
    if (!artworkURL)
    {
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:artworkURL];
    NSHTTPURLResponse *urlResponse = nil;
    NSError *error = nil;
    NSData *data = [PVSynchronousURLSession sendSynchronousRequest:request
                                                 returningResponse:&urlResponse
                                                             error:&error];
    if (error)
    {
        DLog(@"error downloading artwork from: %@ -- %@", url, [error localizedDescription]);
        return;
    }
    
    if ([urlResponse statusCode] != 200)
    {
        DLog(@"HTTP Error: %zd", [urlResponse statusCode]);
        DLog(@"Response: %@", urlResponse);
    }
    
    UIImage *artwork = [[UIImage alloc] initWithData:data];
    if (artwork)
    {
        [PVMediaCache writeImageToDisk:artwork withKey:url];
    }
    
    if (self.finishedArtworkHandler)
    {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.finishedArtworkHandler(url);
        });
    }
}

- (NSArray *)searchDatabaseUsingKey:(NSString *)key value:(NSString *)value systemID:(NSString *)systemID error:(NSError **)error
{
    if (!self.openVGDB)
    {
        self.openVGDB = [[OESQLiteDatabase alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"openvgdb" withExtension:@"sqlite"]
                                                        error:error];
    }
    if (!self.openVGDB)
    {
        DLog(@"Unable to open game database: %@", [*error localizedDescription]);
        return nil;
    }
    
    NSArray *results = nil;
    NSString *exactQuery = @"SELECT DISTINCT releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE %@ = '%@'";
    NSString *likeQuery = @"SELECT DISTINCT romFileName, releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', regionName as 'region', systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE %@ LIKE \"%%%@%%\" AND systemID=\"%@\" ORDER BY case when %@ LIKE \"%@%%\" then 1 else 0 end DESC";
    NSString *queryString = nil;
    
    NSString *dbSystemID = [[PVEmulatorConfiguration sharedInstance] databaseIDForSystemID:systemID];
    
    if ([key isEqualToString:@"romFileName"])
    {
        queryString = [NSString stringWithFormat:likeQuery, key, value, dbSystemID, key, value];
    }
    else
    {
        queryString = [NSString stringWithFormat:exactQuery, key, value];
    }
    
    results = [self.openVGDB executeQuery:queryString
                                    error:error];
    return results;
}

#pragma mark - Utils

- (NSString *)documentsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    
    return [paths firstObject];
}

- (NSString *)romsPath
{
    return [[self documentsPath] stringByAppendingPathComponent:@"roms"];
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

- (BOOL)isCDROM:(ImportCanidateFile *)romFile
{
    BOOL isCDROM = NO;
    
    PVEmulatorConfiguration *emuConfig = [PVEmulatorConfiguration sharedInstance];
    NSArray *cdExtensions = [emuConfig supportedCDFileExtensions];
    NSString *extension = [romFile.filePath pathExtension];
    if ([cdExtensions containsObject:extension])
    {
        isCDROM = YES;
    }
    
    return isCDROM;
}

#pragma mark -

+ (PVGame *)importArtworkFromPath:(NSString *)imageFullPath
{
    BOOL isDirectory = NO;

    if (![NSFileManager.defaultManager fileExistsAtPath:imageFullPath isDirectory:&isDirectory] || isDirectory) {
        return nil;
    }

    NSData *coverArtFullData = [NSData dataWithContentsOfFile:imageFullPath];
    UIImage *coverArtFullImage = [UIImage imageWithData:coverArtFullData];
    UIImage *coverArtScaledImage = [coverArtFullImage scaledImageWithMaxResolution:PVThumbnailMaxResolution];

    if (!coverArtScaledImage) {
        return nil;
    }

    NSData *coverArtScaledData = UIImagePNGRepresentation(coverArtScaledImage);
    NSString *hash = [coverArtScaledData md5Hash];
    [PVMediaCache writeDataToDisk:coverArtScaledData withKey:hash];

    NSString *imageFilename = imageFullPath.lastPathComponent;
    NSString *imageFileExtension = [@"." stringByAppendingString:imageFilename.pathExtension];
    NSString *gameFilename = [imageFilename stringByReplacingOccurrencesOfString:imageFileExtension withString:@""];

    NSString *systemID = [PVEmulatorConfiguration.sharedInstance systemIdentifierForFileExtension:gameFilename.pathExtension];
    NSArray *cdBasedSystems = [[PVEmulatorConfiguration sharedInstance] cdBasedSystemIDs];

    if ([cdBasedSystems containsObject:systemID] && ![gameFilename.pathExtension isEqualToString:@"cue"]) {
        return nil;
    }

    NSString *gamePartialPath = [systemID stringByAppendingPathComponent:gameFilename];

    if (!gamePartialPath) {
        return nil;
    }

    RLMRealm *realm = [RLMRealm defaultRealm];

    NSPredicate *gamePredicate = [NSPredicate predicateWithFormat:@"romPath == %@", gamePartialPath];
    RLMResults *games = [PVGame objectsInRealm:realm withPredicate:gamePredicate];

    if (games.count < 1) {
        return nil;
    }

    PVGame *game = games.firstObject;

    [realm beginWriteTransaction];
    [game setCustomArtworkURL:hash];
    [realm commitWriteTransaction];

    [NSFileManager.defaultManager removeItemAtPath:imageFullPath error:nil];

    return game;
}

@end
