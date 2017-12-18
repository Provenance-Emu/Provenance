//
//  PVEmulatorConfiguration.m
//  Provenance
//
//  Created by James Addyman on 02/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorConfiguration.h"
#import "PVEmulatorConstants.h"

#import <PVGenesis/PVGenesisEmulatorCore.h>
#import "PVGenesisControllerViewController.h"

#import <PVSNES/PVSNESEmulatorCore.h>
#import "PVSNESControllerViewController.h"

#import <PVGBA/PVGBAEmulatorCore.h>
#import "PVGBAControllerViewController.h"

#import <PVGB/PVGBEmulatorCore.h>
#import "PVGBControllerViewController.h"

#import <PVNES/PVNESEmulatorCore.h>
#import "PVNESControllerViewController.h"

#import <PVStella/PVStellaGameCore.h>
#import "PVStellaControllerViewController.h"

#import <ProSystem/ProSystemGameCore.h>
#import "PVAtari7800ControllerViewController.h"

#import <PicoDrive/PicodriveGameCore.h>
#import "PV32XControllerViewController.h"

#import <PVAtari800/ATR800GameCore.h>
#import "PVAtari5200ControllerViewController.h"

#import <PVPokeMini/PVPokeMiniEmulatorCore.h>
#import "PVPokeMiniControllerViewController.h"

#import <PVMednafen/MednafenGameCore.h>
#import "PVPSXControllerViewController.h"
#import "PVLynxControllerViewController.h"
#import "PVPCEControllerViewController.h"
#import "PVVBControllerViewController.h"
#import "PVWonderSwanControllerViewController.h"
#import "PVNeoGeoPocketControllerViewController.h"

@implementation BIOSEntry

-(instancetype)initWithFilename:(NSString * _Nonnull )filename systemID:(NSString* _Nonnull)systemID description:(NSString * _Nonnull )desctription md5:(NSString * _Nonnull )md5 size:(NSNumber * _Nonnull )size;
{
    self = [super init];
    if (self) {
        _filename         = filename;
        _desc             = desctription;
        _expectedMD5      = md5.uppercaseString;
        _expectedFileSize = size;
        _systemID         = systemID;
    }
    return self;
}
@end

@interface PVEmulatorConfiguration ()

@property (nonatomic, strong) NSArray *systems;

@end

@implementation PVEmulatorConfiguration

+ (PVEmulatorConfiguration *)sharedInstance
{
	static PVEmulatorConfiguration *_sharedInstance;
	
	if (!_sharedInstance)
	{
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			_sharedInstance = [[super allocWithZone:nil] init];
		});
	}
	
	return _sharedInstance;
}

- (id)init
{
	if ((self = [super init]))
	{
		self.systems = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"systems" ofType:@"plist"]];
	}
	
	return self;
}

- (void)dealloc
{
    self.systems = nil;
}

- (PVEmulatorCore *)emulatorCoreForSystemIdentifier:(NSString *)systemID
{
	PVEmulatorCore *core = nil;
	
	if ([systemID isEqualToString:PVGenesisSystemIdentifier] ||
        [systemID isEqualToString:PVGameGearSystemIdentifier] ||
        [systemID isEqualToString:PVMasterSystemSystemIdentifier] ||
        [systemID isEqualToString:PVSegaCDSystemIdentifier] ||
        [systemID isEqualToString:PVSG1000SystemIdentifier])
	{
		core = [[PVGenesisEmulatorCore alloc] init];
	}
	else if ([systemID isEqualToString:PVSNESSystemIdentifier])
	{
		core = [[PVSNESEmulatorCore alloc] init];
	}
    else if ([systemID isEqualToString:PVGBASystemIdentifier])
    {
        core = [[PVGBAEmulatorCore alloc] init];
    }
    else if ([systemID isEqualToString:PVGBSystemIdentifier] ||
             [systemID isEqualToString:PVGBCSystemIdentifier])
    {
        core = [[PVGBEmulatorCore alloc] init];
    }
    else if ([systemID isEqualToString:PVNESSystemIdentifier] ||
             [systemID isEqualToString:PVFDSSystemIdentifier])
    {
        core = [[PVNESEmulatorCore alloc] init];
    }
    else if ([systemID isEqualToString:PV2600SystemIdentifier])
    {
        core = [[PVStellaGameCore alloc] init];
    }
    else if ([systemID isEqualToString:PV7800SystemIdentifier])
    {
        core = [[PVProSystemGameCore alloc] init];
    }
    else if ([systemID isEqualToString:PV32XSystemIdentifier])
    {
        core = [[PicodriveGameCore alloc] init];
    }
    else if ([systemID isEqualToString:PV5200SystemIdentifier])
    {
        core = [[ATR800GameCore alloc] init];
    }
    else if ([systemID isEqualToString:PVPokemonMiniSystemIdentifier])
    {
        core = [[PVPokeMiniEmulatorCore alloc] init];
    }
    else if ([systemID isEqualToString:PVPSXSystemIdentifier] ||
             [systemID isEqualToString:PVLynxSystemIdentifier] ||
             [systemID isEqualToString:PVPCESystemIdentifier] ||
             [systemID isEqualToString:PVPCECDSystemIdentifier] ||
             [systemID isEqualToString:PVNGPSystemIdentifier] ||
             [systemID isEqualToString:PVNGPCSystemIdentifier] ||
             [systemID isEqualToString:PVPCFXSystemIdentifier] ||
             [systemID isEqualToString:PVVirtualBoySystemIdentifier] ||
             [systemID isEqualToString:PVWonderSwanSystemIdentifier])
    {
        core = [[MednafenGameCore alloc] init];
    }
	
    core.systemIdentifier = systemID;
    
	return core;
}

- (PVControllerViewController *)controllerViewControllerForSystemIdentifier:(NSString *)systemID
{
	PVControllerViewController *controller = nil;
	
    if ([systemID isEqualToString:PVGenesisSystemIdentifier] ||
        [systemID isEqualToString:PVGameGearSystemIdentifier] ||
        [systemID isEqualToString:PVMasterSystemSystemIdentifier] ||
        [systemID isEqualToString:PVSegaCDSystemIdentifier] ||
        [systemID isEqualToString:PVSG1000SystemIdentifier])
	{
		controller = [[PVGenesisControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
	}
	else if ([systemID isEqualToString:PVSNESSystemIdentifier])
	{
		controller = [[PVSNESControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
	}
    else if ([systemID isEqualToString:PVGBASystemIdentifier])
    {
        controller = [[PVGBAControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVGBSystemIdentifier] ||
             [systemID isEqualToString:PVGBCSystemIdentifier])
    {
        controller = [[PVGBControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVNESSystemIdentifier] ||
             [systemID isEqualToString:PVFDSSystemIdentifier])
    {
        controller = [[PVNESControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PV2600SystemIdentifier])
    {
        controller = [[PVStellaControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PV7800SystemIdentifier])
    {
        controller = [[PVAtari7800ControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PV32XSystemIdentifier])
    {
        controller = [[PV32XControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PV5200SystemIdentifier])
    {
        controller = [[PVAtari5200ControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVPokemonMiniSystemIdentifier])
    {
        controller = [[PVPokeMiniControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVPSXSystemIdentifier])
    {
        controller = [[PVPSXControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVWonderSwanSystemIdentifier])
    {
        controller = [[PVWonderSwanControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVLynxSystemIdentifier])
    {
        controller = [[PVLynxControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVVirtualBoySystemIdentifier])
    {
        controller = [[PVVBControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ([systemID isEqualToString:PVPCESystemIdentifier] ||
             [systemID isEqualToString:PVPCECDSystemIdentifier] ||
             [systemID isEqualToString:PVPCFXSystemIdentifier])
    {
        controller = [[PVPCEControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else if ( [systemID isEqualToString:PVNGPSystemIdentifier] ||
             [systemID isEqualToString:PVNGPCSystemIdentifier]) {
        controller = [[PVNeoGeoPocketControllerViewController alloc] initWithControlLayout:[self controllerLayoutForSystem:systemID] systemIdentifier:systemID];
    }
    else {
        @throw [NSString stringWithFormat:@"No controller for system with identifier %@", systemID];
    }
	
	return controller;
}

- (BOOL)systemIDWantsStartAndSelectInMenu:(NSString *)systemID {
	if ([systemID isEqualToString:PVPSXSystemIdentifier]) {
		return YES;
	}
	
	return NO;
}

- (NSDictionary *)systemForIdentifier:(NSString *)systemID
{
	for (NSDictionary *system in self.systems)
	{
		if ([[system objectForKey:PVSystemIdentifierKey] isEqualToString:systemID])
		{
			return system;
		}
	}
	
	return nil;
}

- (NSString *)systemIDForDatabaseID:(NSString *)databaseID;
{
    for (NSDictionary *system in self.systems)
    {
        NSString *dbID = [system objectForKey:PVDatabaseIDKey];
        if ([dbID isEqualToString:databaseID])
        {
            return system[PVSystemIdentifierKey];
        }
    }
    
    return nil;
}

- (NSArray *)availableSystemIdentifiers
{
	NSMutableArray *systemIDs = [NSMutableArray array];
	
	for (NSDictionary *system in self.systems)
	{
		NSString *systemID = [system objectForKey:PVSystemIdentifierKey];
		[systemIDs addObject:systemID];
	}
	
	return [systemIDs copy];
}

- (NSString *)nameForSystemIdentifier:(NSString *)systemID
{
	NSDictionary *system = [self systemForIdentifier:systemID];
	return [system objectForKey:PVSystemNameKey];
}

- (NSString *)shortNameForSystemIdentifier:(NSString *)systemID
{
	NSDictionary *system = [self systemForIdentifier:systemID];
	return [system objectForKey:PVShortSystemNameKey];
}

- (NSArray *)supportedCDFileExtensions
{
    NSMutableSet *extensions = [NSMutableSet set];
    
    for (NSDictionary *system in self.systems)
    {
        if (system[PVUsesCDsKey])
        {
            [extensions addObjectsFromArray:system[PVSupportedExtensionsKey]];
        }
    }
    
    return [extensions allObjects];
}

- (NSArray *)cdBasedSystemIDs
{
    NSMutableSet *systems = [NSMutableSet set];

    for (NSDictionary *system in self.systems)
    {
        if (system[PVUsesCDsKey])
        {
            [systems addObject:system[PVSystemIdentifierKey]];
        }
    }

    return [systems allObjects];
}

- (NSArray *)supportedROMFileExtensions
{
	NSMutableSet *extentions = [NSMutableSet set];
	
	for (NSDictionary *system in self.systems)
	{
		NSArray *ext = [system objectForKey:PVSupportedExtensionsKey];
		[extentions addObjectsFromArray:ext];
	}
	
	return [extentions allObjects];
}

- (NSArray *)supportedBIOSFileExtensions
{
    NSMutableSet *extentions = [NSMutableSet set];

    for (BIOSEntry *bios in [self biosEntries] ) {
        NSString *ext = bios.filename.pathExtension;
        [extentions addObject:ext];
    }

    return [extentions allObjects];
}


- (NSArray *)fileExtensionsForSystemIdentifier:(NSString *)systemID
{
	NSDictionary *system = [self systemForIdentifier:systemID];
	return [system objectForKey:PVSupportedExtensionsKey];
}

- (NSString *)systemIdentifierForFileExtension:(NSString *)fileExtension
{
	for (NSDictionary *system in self.systems)
	{
		NSArray *supportedROMFileExtensions = [system objectForKey:PVSupportedExtensionsKey];
		if ([supportedROMFileExtensions containsObject:[fileExtension lowercaseString]])
		{
			return [system objectForKey:PVSystemIdentifierKey];
		}
	}
	
	return nil;
}

- (NSArray *)systemIdentifiersForFileExtension:(NSString *)fileExtension
{
    NSMutableArray *systems = [NSMutableArray array];
    for (NSDictionary *system in self.systems)
    {
        NSArray *supportedROMFileExtensions = [system objectForKey:PVSupportedExtensionsKey];
        if ([supportedROMFileExtensions containsObject:[fileExtension lowercaseString]])
        {
            [systems addObject:[system objectForKey:PVSystemIdentifierKey]];
        }
    }
    
    return [systems copy];
}

- (NSArray *)controllerLayoutForSystem:(NSString *)systemID
{
	NSDictionary *system = [self systemForIdentifier:systemID];
	return [system objectForKey:PVControlLayoutKey];
}

- (NSString *)databaseIDForSystemID:(NSString *)systemID
{
    NSDictionary *system = [self systemForIdentifier:systemID];
    return system[PVDatabaseIDKey];
}

-(NSArray<BIOSEntry*>*)biosEntries {
    
    static NSArray<BIOSEntry*>* biosEntries;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<BIOSEntry*>* newEntries = [NSMutableArray new];
        for (NSDictionary *system in self.systems) {
            NSArray<NSDictionary*>*biosDicts = system[PVBIOSNamesKey];
            NSString*systemID                = system[PVSystemIdentifierKey];
            if (biosDicts) {
                for (NSDictionary*biosDict in biosDicts) {
                    
                    NSString* desc = biosDict[@"Description"];
                    NSString* md5  = biosDict[@"MD5"];
                    NSString* name = biosDict[@"Name"];
                    NSNumber* size = biosDict[@"Size"];

                    if (desc && md5 && name && size) {
                        BIOSEntry* newEntry = [[BIOSEntry alloc] initWithFilename:name
                                                                         systemID:systemID
                                                                      description:desc
                                                                              md5:md5
                                                                             size:size];
                        [newEntries addObject:newEntry];
                    } else {
                        DLog(@"System BIOS dictionary was missing a key");
                    }
                }
            }
        }
        biosEntries = [NSArray arrayWithArray:newEntries];
    });
    
    return biosEntries;
}

-(NSArray<BIOSEntry*>*)biosEntriesForSystemIdentifier:(NSString*)systemID {
    NSPredicate*predicate = [NSPredicate predicateWithFormat:@"systemID == %@", systemID];
    
    return [[self biosEntries] filteredArrayUsingPredicate:predicate];
}

- (BIOSEntry* _Nullable)biosEntryForMD5:(NSString* _Nonnull)md5 {
    NSPredicate*predicate = [NSPredicate predicateWithFormat:@"expectedMD5 == %@", md5];
    
    return [[self biosEntries] filteredArrayUsingPredicate:predicate].firstObject;
}

- (BIOSEntry* _Nullable)biosEntryForFilename:(NSString* _Nonnull)filename {
    NSPredicate*predicate = [NSPredicate predicateWithFormat:@"filename == %@", filename];
    
    return [[self biosEntries] filteredArrayUsingPredicate:predicate].firstObject;
}

- (NSString *)BIOSPathForSystemID:(NSString *)systemID
{
    return [[[self documentsPath] stringByAppendingPathComponent:@"BIOS"] stringByAppendingPathComponent:systemID];
}

#pragma mark - Filesystem Helpers
- (NSString *)documentsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (NSString *)romsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return [documentsDirectoryPath stringByAppendingPathComponent:@"roms"];
}

- (NSString *)coverArtPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    
    return [paths.firstObject stringByAppendingPathComponent:@"Cover Art"];
}

- (NSString *)batterySavesPathForROM:(NSString *)romPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *batterySavesDirectory = [documentsDirectoryPath stringByAppendingPathComponent:@"Battery States"];
    
    NSString *romName = [[[romPath lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
    batterySavesDirectory = [batterySavesDirectory stringByAppendingPathComponent:romName];
    
    NSError *error = nil;
    
    [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error)
    {
        DLog(@"Error creating save state directory: %@", [error localizedDescription]);
    }
    
    return batterySavesDirectory;
}

- (NSString *)saveStatePathForROM:(NSString *)romPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *saveStateDirectory = [documentsDirectoryPath stringByAppendingPathComponent:@"Save States"];
    
    NSMutableArray *filenameComponents = [[[romPath lastPathComponent] componentsSeparatedByString:@"."] mutableCopy];
    // remove extension
    [filenameComponents removeLastObject];
    
    NSString *romName = [filenameComponents componentsJoinedByString:@"."];
    saveStateDirectory = [saveStateDirectory stringByAppendingPathComponent:romName];
    
    NSError *error = nil;
    
    [[NSFileManager defaultManager] createDirectoryAtPath:saveStateDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error)
    {
        DLog(@"Error creating save state directory: %@", [error localizedDescription]);
    }
    
    return saveStateDirectory;
}

@end
