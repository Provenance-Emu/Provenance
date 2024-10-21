//
//  PVTGBDualCore+Controls.h
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualBridge.h"
@import Foundation;

typedef enum PVGBButton: NSInteger PVGBButton;

@interface PVTGBDualBridge (Controls)

- (void)didPushGBButton:(PVGBButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGBButton:(PVGBButton)button forPlayer:(NSInteger)player;
- (void)pollControllers;

@end
