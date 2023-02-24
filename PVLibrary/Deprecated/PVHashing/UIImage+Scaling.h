//
//  UIImage+Scaling.h
//  Provenance
//
//  Created by James Addyman on 09/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>

@interface UIImage (Scaling)

- (UIImage *)scaledImageWithMaxResolution:(NSInteger)maxResolution;

@end
#endif
