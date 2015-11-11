//
//  PVEmulatorConfiguration.h
//  Provenance
//
//  Created by James Addyman on 02/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PVEmulatorCore, PVControllerViewController;

extern NSString * const PVSystemNameKey;
extern NSString * const PVShortSystemNameKey;
extern NSString * const PVSystemIdentifierKey;
extern NSString * const PVDatabaseIDKey;
extern NSString * const PVUsesCDsKey;
extern NSString * const PVRequiresBIOSKey;
extern NSString * const PVBIOSNamesKey;
extern NSString * const PVSupportedExtensionsKey;
extern NSString * const PVControlLayoutKey;
extern NSString * const PVControlTypeKey;
extern NSString * const PVControlSizeKey;
extern NSString * const PVGroupedButtonsKey;
extern NSString * const PVControlFrameKey;
extern NSString * const PVControlTitleKey;

extern NSString * const PVButtonGroup;
extern NSString * const PVButton;
extern NSString * const PVDPad;
extern NSString * const PVStartButton;
extern NSString * const PVSelectButton;
extern NSString * const PVLeftShoulderButton;
extern NSString * const PVRightShoulderButton;

extern NSString * const PVGenesisSystemIdentifier;
extern NSString * const PVGameGearSystemIdentifier;
extern NSString * const PVMasterSystemSystemIdentifier;
extern NSString * const PVSegaCDSystemIdentifier;
extern NSString * const PVSNESSystemIdentifier;
extern NSString * const PVGBASystemIdentifier;
extern NSString * const PVGBSystemIdentifier;
extern NSString * const PVGBCSystemIdentifier;
extern NSString * const PVNESSystemIdentifier;
extern NSString * const PVFDSSystemIdentifier;
extern NSString * const PVSG1000SystemIdentifier;

@interface PVEmulatorConfiguration : NSObject

+ (PVEmulatorConfiguration *)sharedInstance;

- (PVEmulatorCore *)emulatorCoreForSystemIdentifier:(NSString *)systemID;
- (PVControllerViewController *)controllerViewControllerForSystemIdentifier:(NSString *)systemID;

- (NSDictionary *)systemForIdentifier:(NSString *)systemID;
- (NSArray *)availableSystemIdentifiers;
- (NSString *)nameForSystemIdentifier:(NSString *)systemID;
- (NSString *)shortNameForSystemIdentifier:(NSString *)systemID;
- (NSArray *)supportedFileExtensions;
- (NSArray *)supportedCDFileExtensions;
- (NSArray *)cdBasedSystemIDs;
- (NSArray *)fileExtensionsForSystemIdentifier:(NSString *)systemID;
- (NSString *)systemIdentifierForFileExtension:(NSString *)fileExtension;
- (NSArray *)systemIdentifiersForFileExtension:(NSString *)fileExtension;
- (NSArray *)controllerLayoutForSystem:(NSString *)systemID;
- (NSString *)databaseIDForSystemID:(NSString *)systemID;

@end
