//
//  PVEmulatorConfiguration.m
//  Provenance
//
//  Created by James Addyman on 02/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorConfiguration.h"

#import "PVGenesisEmulatorCore.h"
#import "PVGenesisControllerViewController.h"

#import "PVSNESEmulatorCore.h"
#import "PVSNESControllerViewController.h"

#import "PVGBAEmulatorCore.h"
#import "PVGBAControllerViewController.h"

#import "PVGBEmulatorCore.h"
#import "PVGBControllerViewController.h"

#import "PVNESEmulatorCore.h"
#import "PVNESControllerViewController.h"

NSString * const PVSystemNameKey = @"PVSystemName";
NSString * const PVShortSystemNameKey = @"PVShortSystemName";
NSString * const PVSystemIdentifierKey = @"PVSystemIdentifier";
NSString * const PVDatabaseIDKey = @"PVDatabaseID";
NSString * const PVUsesCDsKey = @"PVUsesCDs";
NSString * const PVRequiresBIOSKey = @"PVRequiresBIOS";
NSString * const PVBIOSNamesKey = @"PVBIOSNames";
NSString * const PVSupportedExtensionsKey = @"PVSupportedExtensions";
NSString * const PVControlLayoutKey = @"PVControlLayout";
NSString * const PVControlTypeKey = @"PVControlType";
NSString * const PVControlSizeKey = @"PVControlSize";
NSString * const PVGroupedButtonsKey = @"PVGroupedButtons";
NSString * const PVControlFrameKey = @"PVControlFrame";
NSString * const PVControlTitleKey = @"PVControlTitle";

NSString * const PVButtonGroup = @"PVButtonGroup";
NSString * const PVButton = @"PVButton";
NSString * const PVDPad = @"PVDPad";
NSString * const PVStartButton = @"PVStartButton";
NSString * const PVSelectButton = @"PVSelectButton";
NSString * const PVLeftShoulderButton = @"PVLeftShoulderButton";
NSString * const PVRightShoulderButton = @"PVRightShoulderButton";

NSString * const PVGenesisSystemIdentifier = @"com.provenance.genesis";
NSString * const PVGameGearSystemIdentifier = @"com.provenance.gamegear";
NSString * const PVMasterSystemSystemIdentifier = @"com.provenance.mastersystem";
NSString * const PVSegaCDSystemIdentifier = @"com.provenance.segacd";
NSString * const PVSNESSystemIdentifier = @"com.provenance.snes";
NSString * const PVGBASystemIdentifier = @"com.provenance.gba";
NSString * const PVGBSystemIdentifier = @"com.provenance.gb";
NSString * const PVGBCSystemIdentifier = @"com.provenance.gbc";
NSString * const PVNESSystemIdentifier = @"com.provenance.nes";
NSString * const PVFDSSystemIdentifier = @"com.provenance.fds";
NSString * const PVSG1000SystemIdentifier = @"com.provenance.sg1000";


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
	
	return controller;
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

- (NSArray *)supportedFileExtensions
{
	NSMutableSet *extentions = [NSMutableSet set];
	
	for (NSDictionary *system in self.systems)
	{
		NSArray *ext = [system objectForKey:PVSupportedExtensionsKey];
		[extentions addObjectsFromArray:ext];
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
		NSArray *supportedFileExtensions = [system objectForKey:PVSupportedExtensionsKey];
		if ([supportedFileExtensions containsObject:[fileExtension lowercaseString]])
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
        NSArray *supportedFileExtensions = [system objectForKey:PVSupportedExtensionsKey];
        if ([supportedFileExtensions containsObject:[fileExtension lowercaseString]])
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

@end
