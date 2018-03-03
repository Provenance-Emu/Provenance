//
//  UIImage+Color.h
//  Provenance
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Color)
+ (UIImage *_Nonnull)imageWithSize:(CGSize)size
                             color:(UIColor *_Nonnull)color
                              text:(NSAttributedString *_Nonnull)text;
@end
