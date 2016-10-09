//
//  UIImage+Color.h
//  Provenance
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Color)
+ (UIImage *)imageWithSize:(CGSize)size
                     color:(UIColor *)color
                      text:(NSAttributedString *)text;
@end
