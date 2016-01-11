//
//  PVEmulatorConfiguration.h
//  Provenance
//
//  Created by James Addyman on 02/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PVEmulatorCore, PVControllerViewController;

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
