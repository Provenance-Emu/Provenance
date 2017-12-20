//
//  PVEmulatorConfiguration.h
//  Provenance
//
//  Created by James Addyman on 02/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PVEmulatorCore, PVControllerViewController;

@interface BIOSEntry : NSObject

@property (nonatomic, strong, nonnull, readonly) NSString* systemID;
@property (nonatomic, strong, nonnull, readonly) NSString* desc;
@property (nonatomic, strong, nonnull, readonly) NSString* filename;
@property (nonatomic, strong, nonnull, readonly) NSNumber* expectedFileSize;
@property (nonatomic, strong, nonnull, readonly) NSString* expectedMD5;

-(instancetype _Nonnull)initWithFilename:(NSString * _Nonnull )filename systemID:(NSString* _Nonnull)systemID description:(NSString * _Nonnull )desctription md5:(NSString * _Nonnull )md5 size:(NSNumber * _Nonnull )size;
@end

@interface PVEmulatorConfiguration : NSObject

+ (instancetype _Nonnull)sharedInstance;

- (PVEmulatorCore * _Nullable)emulatorCoreForSystemIdentifier:(NSString * _Nonnull)systemID;
- (PVControllerViewController * _Nullable)controllerViewControllerForSystemIdentifier:(NSString * _Nonnull)systemID;

#pragma mark System
- (NSDictionary * _Nullable)systemForIdentifier:(NSString * _Nonnull)systemID;
- (NSArray * _Nonnull)availableSystemIdentifiers;
- (NSString * _Nullable)nameForSystemIdentifier:(NSString* _Nonnull)systemID;
- (NSString * _Nullable)shortNameForSystemIdentifier:(NSString * _Nonnull)systemID;
- (NSArray * _Nullable)controllerLayoutForSystem:(NSString * _Nonnull)systemID;
- (BOOL)systemIDWantsStartAndSelectInMenu:(NSString * _Nonnull)systemID;
- (NSString * _Nullable)databaseIDForSystemID:(NSString * _Nonnull)systemID;
- (NSString *)systemIDForDatabaseID:(NSString *)databaseID;

#pragma mark ROM IOS etc
- (NSArray * _Nonnull)supportedROMFileExtensions;
- (NSArray * _Nonnull)supportedCDFileExtensions;
- (NSArray * _Nonnull)cdBasedSystemIDs;
- (NSArray * _Nullable)fileExtensionsForSystemIdentifier:(NSString * _Nonnull)systemID;
- (NSString * _Nullable)systemIdentifierForFileExtension:(NSString * _Nonnull)fileExtension;
- (NSArray * _Nonnull)systemIdentifiersForFileExtension:(NSString * _Nonnull)fileExtension;

#pragma mark BIOS
- (NSArray * _Nonnull)supportedBIOSFileExtensions;

- (NSArray<BIOSEntry*>* _Nonnull)biosEntries;
- (NSArray<BIOSEntry*>* _Nonnull)biosEntriesForSystemIdentifier:(NSString* _Nonnull)systemID;
- (BIOSEntry* _Nullable)biosEntryForMD5:(NSString* _Nonnull)md5;
- (BIOSEntry* _Nullable)biosEntryForFilename:(NSString* _Nonnull)filename;
- (NSString * _Nonnull)BIOSPathForSystemID:(NSString * _Nonnull)systemID;

#pragma mark Filesystem Helpers
- (NSString * _Nonnull)documentsPath;
- (NSString * _Nonnull)romsPath;
- (NSString * _Nonnull)coverArtPath;
- (NSString * _Nonnull)batterySavesPathForROM:(NSString * _Nonnull)romPath;
- (NSString * _Nonnull)saveStatePathForROM:(NSString * _Nonnull)romPath;
@end
