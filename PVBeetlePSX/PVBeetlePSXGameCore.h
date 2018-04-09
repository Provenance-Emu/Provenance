//
//  PVBeetlePSXGameCore.h
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 4/9/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>

@class OERingBuffer;

typedef NS_ENUM(NSInteger, MednaSystem) {
	MednaSystemGB,
	MednaSystemGBA,
	MednaSystemGG,
	MednaSystemLynx,
	MednaSystemMD,
	MednaSystemNES,
	MednaSystemNeoGeo,
	MednaSystemPCE,
	MednaSystemPCFX,
	MednaSystemSMS,
	MednaSystemPSX,
	MednaSystemVirtualBoy,
	MednaSystemWonderSwan
};

__attribute__((visibility("default")))
@interface PVBeetlePSXGameCore : PVEmulatorCore

@property (nonatomic) BOOL isStartPressed;
@property (nonatomic) BOOL isSelectPressed;

@end

// for Swiwt
@interface PVBeetlePSXGameCore()
@property (nonatomic, assign) NSUInteger maxDiscs;
-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
@end
