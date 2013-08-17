//
//  UIAlertView+BlockAdditions.h
//  Provenance
//
//  Created by James Addyman on 15/06/2012.
//  Copyright (c) 2012 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef void(^PVUIAlertViewCompletionHandler)(NSUInteger buttonIndex);

@interface UIAlertView (PVBlockAdditions)

- (PVUIAlertViewCompletionHandler)PV_completionHandler;
- (void)PV_setCompletionHandler:(PVUIAlertViewCompletionHandler)handler;

@end
