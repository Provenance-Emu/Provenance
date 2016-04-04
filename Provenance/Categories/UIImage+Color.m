//
//  UIImage+Color.m
//  Provenance
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "UIImage+Color.h"

@implementation UIImage (Color)

+ (UIImage *)imageWithSize:(CGSize)size
                     color:(UIColor *)color
                      text:(NSAttributedString *)text {
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextSetStrokeColorWithColor(context, [[UIColor colorWithWhite:0.7 alpha:0.6] CGColor]);
    CGContextSetLineWidth(context, 0.5);
    CGContextFillRect(context, rect);
    
    CGRect boundingRect = [text boundingRectWithSize:rect.size
                                             options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin
                                             context:NULL];
    boundingRect.origin = CGPointMake(CGRectGetMidX(rect) - (CGRectGetWidth(boundingRect) / 2),
                                      CGRectGetMidY(rect) - (CGRectGetHeight(boundingRect) / 2));
    [text drawInRect:boundingRect];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
