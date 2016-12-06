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
