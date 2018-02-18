//
//  PVGameImporter.m
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVGameImporter.h"
#import "Provenance-Swift.h"
#import "OESQLiteDatabase.h"
#import "NSFileManager+Hashing.h"
#import "PVSynchronousURLSession.h"
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

//@interface ImportCanidateFile : NSObject
//@property (nonatomic, strong, nonnull) NSString *filePath;
//@property (nonatomic, strong, nonnull) NSString *md5;
//
//- (instancetype)initWithFilePath:(NSString* _Nonnull)filePath;
//@end
//
//
//@implementation ImportCanidateFile {
//    NSString * _hastStore;
//    dispatch_once_t _hashToken;
//
//}
//
//- (instancetype)initWithFilePath:(NSString* _Nonnull)filePath
//{
//    self = [super init];
//    if (self) {
//        _filePath = filePath;
//    }
//    return self;
//}
//
//-(NSString* _Nonnull)md5 {
//    dispatch_once(&_hashToken, ^{
//        if (_hastStore == nil) {
//            NSFileManager *fm = [NSFileManager defaultManager];
//            _hastStore = [fm MD5ForFileAtPath:_filePath fromOffset:0];
//        }
//    });
//
//    return _hastStore;
//}
//
//@end

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
        _romExtensionToSystemsMap    = [self updateRomToSystemMap];
    }
    return self;
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

//- (NSArray *)moveCDROMToAppropriateSubfolder:(ImportCanidateFile *)canidateFile
//{
//    NSMutableArray *newPaths = [NSMutableArray array];
//
//    NSArray *systemsForExtension = [self systemIDsForRomAtPath:canidateFile.filePath];
//
//    NSString *systemID = nil;
//    NSString *subfolderPath = nil;
//
//    if ([systemsForExtension count] > 1)
//    {
//        // Try to match by MD5 or filename
//        NSString*systemID = [self systemIdForROMCanidate:canidateFile];
//
//        if (systemID != nil) {
//            subfolderPath = self.systemToPathMap[systemID];
//        }
//        else {
//            // No MD5 match, so move to conflict dir
//            subfolderPath = [self conflictPath];
//            self.encounteredConflicts = YES;
//        }
//    }
//    else
//    {
//        systemID = [systemsForExtension firstObject];
//        subfolderPath = self.systemToPathMap[systemID];
//    }
//
//    if (![subfolderPath length])
//    {
//        return nil;
//    }
//
//    NSError *error = nil;
//    if (![[NSFileManager defaultManager] createDirectoryAtPath:subfolderPath
//                                   withIntermediateDirectories:YES
//                                                    attributes:nil
//                                                         error:&error])
//    {
//        DLog(@"Unable to create %@ - %@", subfolderPath, [error localizedDescription]);
//        return nil;
//    }
//
//    NSString *sourcePath = [[self romsPath] stringByAppendingPathComponent:canidateFile.filePath.lastPathComponent];
//    NSString *destinationPath = [subfolderPath stringByAppendingPathComponent:canidateFile.filePath.lastPathComponent];
//
//    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
//        [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
//    }
//
//    if (![[NSFileManager defaultManager] moveItemAtPath:sourcePath
//                                                 toPath:destinationPath
//                                                  error:&error])
//    {
//        ELOG(@"Unable to move file from %@ to %@ - %@", canidateFile, subfolderPath, [error localizedDescription]);
//        return nil;
//    } else {
//        DLOG("Moved file %@ to %@", sourcePath, destinationPath);
//    }
//
//    NSString *cueSheetPath = [subfolderPath stringByAppendingPathComponent:canidateFile.filePath];
//    if (!self.encounteredConflicts)
//    {
//        [newPaths addObject:cueSheetPath];
//    }
//
//    // moved the .cue, now move .bins .imgs etc
//    [self moveFilesSimiliarToFilename:canidateFile.filePath.lastPathComponent
//                        fromDirectory:[self romsPath]
//                          toDirectory:subfolderPath
//                             cuesheet:cueSheetPath];
//
//    return [newPaths copy];
//}

//-(void)moveFilesSimiliarToFilename:(NSString* _Nonnull)filename fromDirectory:(NSString* _Nonnull)from toDirectory:(NSString* _Nonnull)to cuesheet:(NSString*)cueSheetPath{
//    NSError*error;
//    NSString *relatedFileName = [filename stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@",[filename pathExtension]] withString:@""];
//    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[PVEmulatorConfiguration romsImportPath].path error:&error];
//
//    if (!contents)
//    {
//        DLog(@"Error scanning %@, %@", [PVEmulatorConfiguration romsImportPath].path, [error localizedDescription]);
//        return;
//    }
//
//    for (NSString *file in contents)
//    {
//        NSString *fileWithoutExtension = [file stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@",[file pathExtension]] withString:@""];
//
//        // Some cue's have multiple bins, like, Game.cue Game (Track 1).bin, Game (Track 2).bin ....
//        // Clip down the file name to the length of the .cue to see if they start to match
//        if (fileWithoutExtension.length > relatedFileName.length) {
//            fileWithoutExtension = [fileWithoutExtension substringWithRange:NSMakeRange(0, relatedFileName.length)];
//        }
//
//        if ([fileWithoutExtension isEqual:relatedFileName])
//        {
//            // Before moving the file, make sure the cue sheet's reference uses the same case.
//            if (cueSheetPath) {
//                NSMutableString *cuesheet = [NSMutableString stringWithContentsOfFile:cueSheetPath encoding:NSUTF8StringEncoding error:&error];
//                if (cuesheet)
//                {
//                    NSRange range = [cuesheet rangeOfString:file options:NSCaseInsensitiveSearch];
//                    [cuesheet replaceCharactersInRange:range withString:file];
//                    if (![cuesheet writeToFile:cueSheetPath
//                                    atomically:NO
//                                      encoding:NSUTF8StringEncoding
//                                         error:&error])
//                    {
//                        DLog(@"Unable to rewrite cuesheet %@ because %@", cueSheetPath, [error localizedDescription]);
//                    }
//                }
//                else
//                {
//                    DLog(@"Unable to read cue sheet %@ because %@", cueSheetPath, [error localizedDescription]);
//                }
//            }
//
//            if (![[NSFileManager defaultManager] moveItemAtPath:[[PVEmulatorConfiguration romsImportPath].path stringByAppendingPathComponent:file] toPath:[to stringByAppendingPathComponent:file] error:&error])
//            {
//                ELOG(@"Unable to move file from %@ to %@ - %@", filename, to, [error localizedDescription]);
//            } else {
//                DLOG(@"Moved file from %@ to %@", filename, to);
//            }
//        }
//    }
//}

//- (BIOSEntry*)moveIfBIOS:(ImportCanidateFile*)canidateFile {
//    PVEmulatorConfiguration *config = [PVEmulatorConfiguration sharedInstance];
//
//    BIOSEntry *bios;
//
//    // Check if BIOS by filename - should possibly just only check MD5?
//    if ((bios = [config biosEntryForFilename:canidateFile.filePath.lastPathComponent])) {
//        return bios;
//    } else {
//        // Now check by MD5
//        NSString *fileMD5 = canidateFile.md5;
//        if ((bios = [config biosEntryForMD5:fileMD5])) {
//            return bios;
//        }
//    }
//
//    return nil;
//}
//
//- (NSString *)moveROMToAppropriateSubfolder:(ImportCanidateFile*)canidateFile
//{
//    NSString *filePath = canidateFile.filePath;
//    NSString *newPath = nil;
//
//    NSArray *systemsForExtension = [self systemIDsForRomAtPath:filePath];
//
//    NSString *systemID = nil;
//    NSString *subfolderPath = nil;
//
//    NSFileManager*fm = [NSFileManager defaultManager];
//
//    // Check first if known BIOS
//    BIOSEntry *biosEntry = [self moveIfBIOS:canidateFile];
//    if (biosEntry) {
//
//        PVEmulatorConfiguration*config = [PVEmulatorConfiguration sharedInstance];
//        NSString *biosDirectory = [config BIOSPathForSystemID:biosEntry.systemID];
//        NSString *destiaionPath = [biosDirectory stringByAppendingPathComponent:biosEntry.filename];
//
//        NSError *error = nil;
//
//        if (![fm fileExistsAtPath:biosDirectory]) {
//            [fm createDirectoryAtPath:biosDirectory
//          withIntermediateDirectories:YES
//                           attributes:nil
//                                error:&error];
//
//            if (error) {
//                DLog(@"Unable to create BIOS directory %@, %@", biosDirectory, error.localizedDescription);
//            }
//        }
//
//        if (![fm moveItemAtPath:filePath
//                         toPath:destiaionPath
//                          error:&error])
//        {
//            if ([error code] == NSFileWriteFileExistsError)
//            {
//                DLog(@"Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, [error localizedDescription]);
//            }
//        } else {
//            DLOG("Moved file %@ to %@", filePath, destiaionPath);
//        }
//        return nil;
//    }
//
//    if ([systemsForExtension count] > 1)
//    {
//        
//        // Check by MD5
//        NSString *fileMD5 = canidateFile.md5.uppercaseString;
//        NSArray *results;
//        for (NSString *system in systemsForExtension) {
//            NSError* error;
//            // TODO: Would be better performance to search EVERY system MD5 in a single query?
//            results = [self searchDatabaseUsingKey:@"romHashMD5"
//                                             value:fileMD5
//                                          systemID:system
//                                             error:&error];
//            break;
//        }
//
//        if (results.count) {
//            NSDictionary *chosenResult = nil;
//            for (NSDictionary *result in results)
//            {
//                if ([result[@"region"] isEqualToString:@"USA"])
//                {
//                    chosenResult = result;
//                    break;
//                }
//            }
//
//            if (!chosenResult)
//            {
//                chosenResult = [results firstObject];
//            }
//
//
//        }
//
//        subfolderPath = [self conflictPath];
//        self.encounteredConflicts = YES;
//    }
//    else
//    {
//        systemID = [systemsForExtension firstObject];
//        subfolderPath = self.systemToPathMap[systemID];
//    }
//
//    if (![subfolderPath length])
//    {
//        return nil;
//    }
//
//    NSError *error = nil;
//    if (![fm createDirectoryAtPath:subfolderPath
//       withIntermediateDirectories:YES
//                        attributes:nil
//                             error:&error])
//    {
//        DLog(@"Unable to create %@ - %@", subfolderPath, [error localizedDescription]);
//        return nil;
//    }
//
//    NSString *destination = [subfolderPath stringByAppendingPathComponent:filePath.lastPathComponent];
//
//    if (![fm moveItemAtPath:filePath toPath:destination error:&error])
//    {
//
//        if ([error code] == NSFileWriteFileExistsError)
//        {
//            if (![fm removeItemAtPath:filePath error:&error])
//            {
//                DLog(@"Unable to delete %@ (after trying to move and getting 'file exists error', because %@", filePath, [error localizedDescription]);
//            }
//        }
//
//        ELOG(@"Unable to move file from %@ to %@ - %@", filePath, subfolderPath, [error localizedDescription]);
//        return nil;
//    } else {
//        DLOG(@"Moved file %@ to %@", filePath, destination);
//    }
//
//    if (!self.encounteredConflicts)
//    {
//      newPath = [subfolderPath stringByAppendingPathComponent:filePath.lastPathComponent];
//    }
//
//    return newPath;
//}

- (NSArray *)conflictedFiles
{
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self conflictPath].path error:&error];
    if (!contents)
    {
        DLOG(@"Unable to get contents of %@ because %@", [self conflictPath], [error localizedDescription]);
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
        
        NSString * sourcePath = [[self conflictPath].path stringByAppendingPathComponent:filePath];
        NSString *destinationPath = [subfolder stringByAppendingPathComponent:filePath];
        if (![[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:destinationPath error:&error])
        {
            ELOG(@"Unable to move %@ to %@ because %@", filePath, subfolder, [error localizedDescription]);
        } else {
            DLOG(@"Moved file %@ to %@.", sourcePath, destinationPath);
        }
        
        // moved the .cue, now move .bins .imgs etc
        NSString *cueSheetPath = [subfolder stringByAppendingPathComponent:filePath];
        NSString *relatedFileName = filePath.stringByDeletingPathExtension;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self conflictPath].path error:&error];
        
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
                
                if (![[NSFileManager defaultManager] moveItemAtPath:[[self conflictPath].path stringByAppendingPathComponent:file] toPath:[subfolder stringByAppendingPathComponent:file] error:&error])
                {
                    ELOG(@"Unable to move file from %@ to %@ - %@", filePath, subfolder, [error localizedDescription]);
                }
            }
        }
        
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.serialImportQueue, ^{
            [weakSelf getRomInfoForFilesAtPaths:@[[NSURL fileURLWithPath:filePath isDirectory:NO]] userChosenSystem:systemID];
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

//- (void)getRomInfoForFilesAtPaths:(NSArray *)paths userChosenSystem:(NSString *)chosenSystemID
//{
//    RomDatabase *database = [RomDatabase temporaryDatabaseContext];
//    [database refresh];
//
//    for (NSString *path in paths)
//    {
//        BOOL isDirectory = ![path containsString:@"."];
//
//        if ([path hasPrefix:@"."] || isDirectory)
//        {
//            continue;
//        }
//
//        @autoreleasepool {
//            NSString *systemID = nil;
//            if (![chosenSystemID length])
//            {
//                systemID = [[PVEmulatorConfiguration sharedInstance] singleSystemIdentifierForFileExtension:[path pathExtension]];
//            }
//            else
//            {
//                systemID = chosenSystemID;
//            }
//
//            NSArray * cdBasedSystems = [[PVEmulatorConfiguration sharedInstance] cdBasedSystemIDs];
//            if ([cdBasedSystems containsObject:systemID] &&
//                ([[path pathExtension] isEqualToString:@"cue"] == NO))
//            {
//                continue;
//            }
//
//            NSString *partialPath = [systemID stringByAppendingPathComponent:[path lastPathComponent]];
//            NSString *title = [[path lastPathComponent] stringByReplacingOccurrencesOfString:[@"." stringByAppendingString:[path pathExtension]] withString:@""];
//            PVGame *game = nil;
//
//            RLMResults *results = [database objectsOfType:[PVGame class] predicate:[NSPredicate predicateWithFormat:@"romPath == %@", ([partialPath length]) ? partialPath : @""]];
//
//            if ([results count])
//            {
//                game = [results firstObject];
//            }
//            else
//            {
//                if (![systemID length])
//                {
//                    continue;
//                }
//
//                game = [[PVGame alloc] init];
//                [game setRomPath:partialPath];
//                [game setTitle:title];
//                [game setSystemIdentifier:systemID];
//                [game setRequiresSync:YES];
//
//                [database addWithObject:game
//                                  error:nil];
//            }
//
//            BOOL modified = NO;
//            if ([game requiresSync])
//            {
//                if (self.importStartedHandler)
//                {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        self.importStartedHandler(path);
//                    });
//                }
//
//                [self lookupInfoForGame:game];
//                modified = YES;
//            }
//
//            if (self.finishedImportHandler)
//            {
//                NSString *md5 = [game md5Hash];
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    self.finishedImportHandler(md5, modified);
//                });
//            }
//
//            [self getArtworkFromURL:[game originalArtworkURL]];
//        }
//    }
//}

//- (void)lookupInfoForGame:(PVGame *)game
//{
//    RomDatabase *database = RomDatabase.temporaryDatabaseContext;
//    [database refresh];
//
//    // Not sure if still needed unless you're creating PVGame's that aren't imported
//    // since MD5 has to be set before import
////    if (![[game md5Hash] length])
////    {
////        NSString *_Nullable md5 = [self calculateMD5ForGame:game];
////
////        if (md5Hash != nil) {
////            [database writeTransactionAndReturnError:nil :^{
////                [game setMd5Hash:md5Hash];
////            }];
////        } else {
////            ELOG("MD5 for Rom was nil at path: %@", romPath);
////        }
////    }
//
//    NSError *error = nil;
//    NSArray *results = nil;
//
//    if ([[game md5Hash] length])
//    {
//        results = [self searchDatabaseUsingKey:@"romHashMD5"
//                                         value:[[game md5Hash] uppercaseString]
//                                      systemID:[game systemIdentifier]
//                                         error:&error];
//    }
//
//    if (![results count])
//    {
//        NSString *fileName = [[game romPath] lastPathComponent];
//
//        // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
//        static NSMutableCharacterSet *charSet = nil;
//        static dispatch_once_t onceToken;
//        dispatch_once(&onceToken, ^{
//            charSet = [NSMutableCharacterSet punctuationCharacterSet];
//            [charSet removeCharactersInString:@"-+&.'"];
//        });
//
//        NSRange nonCharRange = [fileName rangeOfCharacterFromSet:charSet];
//        NSUInteger gameTitleLen;
//        if (nonCharRange.length > 0 && nonCharRange.location > 1) {
//            gameTitleLen = nonCharRange.location - 1;
//        } else {
//            gameTitleLen = [fileName length];
//        }
//        fileName = [fileName substringToIndex:gameTitleLen];
//        results = [self searchDatabaseUsingKey:@"romFileName"
//                                         value:fileName
//                                      systemID:[game systemIdentifier]
//                                         error:&error];
//    }
//
//    if (![results count])
//    {
//        DLog(@"Unable to find ROM (%@) in DB", [game romPath]);
//
//        [RomDatabase.sharedInstance writeTransactionAndReturnError:nil :^{
//            [game setRequiresSync:NO];
//        }];
//
//        return;
//    }
//
//    NSDictionary *chosenResult = nil;
//    for (NSDictionary *result in results)
//    {
//        if ([result[@"region"] isEqualToString:@"USA"])
//        {
//            chosenResult = result;
//            break;
//        }
//    }
//
//    if (!chosenResult)
//    {
//        chosenResult = [results firstObject];
//    }
//
//    [RomDatabase.sharedInstance writeTransactionAndReturnError:nil :^{
//        [game setRequiresSync:NO];
//        if ([chosenResult[@"gameTitle"] length])
//        {
//            [game setTitle:chosenResult[@"gameTitle"]];
//        }
//        if ([chosenResult[@"boxImageURL"] length])
//        {
//            [game setOriginalArtworkURL:chosenResult[@"boxImageURL"]];
//        }
//    }];
//}

- (void)getArtworkFromURL:(NSString *)url
{
    if (![url length] || [PVMediaCache fileExistsForKey:url])
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
        [PVMediaCache writeImageToDisk:artwork withKey:url error:nil];
    }
    
    if (self.finishedArtworkHandler)
    {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.finishedArtworkHandler(url);
        });
    }
}

#pragma mark - Utils

- (NSDictionary *)updateSystemToPathMap
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSString *systemID in [PVEmulatorConfiguration availableSystemIdentifiers])
    {
        NSString *path = [[self documentsPath].path stringByAppendingPathComponent:systemID];
        map[systemID] = path;
    }
    
    return [map copy];
}

- (NSDictionary *)updateRomToSystemMap
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    
    for (NSString *systemID in [PVEmulatorConfiguration availableSystemIdentifiers])
    {
        for (NSString *fileExtension in [PVEmulatorConfiguration fileExtensionsForSystemIdentifier:systemID])
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

@end
