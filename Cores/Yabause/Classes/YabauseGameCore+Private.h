//
//  YabauseGameCore+Private.h
//  PVYabause
//
//  Created by Joseph Mattiello on 3/23/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

#import <PVYabause/PVYabause-Swift.h>

@interface PVYabauseGameCore() <PVYabauseObjC>

@end

@import Foundation;
@import PVSupport;
@import Yabause;

    //#import <PVSupport/PVSupport-Swift.h>

@protocol PVYabauseObjC <NSObject>
- (void)initYabauseWithCDCore:(int)cdcore;
- (void)setupEmulation;
- (void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
    @end
    //#import <PVYabause/PVYabause-Swift.h>
    //@class PVYabauseGameCore;

extern yabauseinit_struct yinit;
extern PerPad_struct *c1, *c2;

@interface PVYabauseGameCore(ObjC)
- (void)initYabauseWithCDCore:(int)cdcore;
- (void)setupEmulation;
- (void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
    @end
