//
//  UIDevice+Hardware.h
//  Provenance
//
//  Created by James Addyman on 24/09/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (Hardware)

- (NSString *)modelIdentifier;
+ (BOOL)isIphone7or7Plus;

@end
