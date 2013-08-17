//
//  UIAlertView+BlockAdditions.m
//  Provenance
//
//  Created by James Addyman on 15/06/2012.
//  Copyright (c) 2012 James Addyman. All rights reserved.
//

#import "UIAlertView+BlockAdditions.h"
#import <objc/runtime.h>

NSString * const PVUIAlertViewCompletionHandlerKey = @"PVUIAlertViewCompletionHandlerKey";

@implementation UIAlertView (PVUIAlertViewCategory)

- (PVUIAlertViewCompletionHandler)PV_completionHandler{
    PVUIAlertViewCompletionHandler handler = (PVUIAlertViewCompletionHandler)objc_getAssociatedObject(self, (__bridge const void *)(PVUIAlertViewCompletionHandlerKey));
    return handler;
}

- (void)PV_setCompletionHandler:(PVUIAlertViewCompletionHandler)handler{
    
    self.delegate = (id<UIAlertViewDelegate>)self;
    
    objc_setAssociatedObject(self, (__bridge const void *)PVUIAlertViewCompletionHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    
    PVUIAlertViewCompletionHandler handler = (PVUIAlertViewCompletionHandler)objc_getAssociatedObject(self, (__bridge const void *)PVUIAlertViewCompletionHandlerKey);
    
    if(handler)
    {
        handler(buttonIndex);
    }
    
    objc_setAssociatedObject(self, (__bridge const void *)PVUIAlertViewCompletionHandlerKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
