//
//  NSObject+PVAbstractAdditions.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (PVAbstractAdditions)

+ (void)doesNotImplementSelector:(SEL)aSel;
+ (void)doesNotImplementOptionalSelector:(SEL)aSel;

- (void)doesNotImplementSelector:(SEL)aSel;
- (void)doesNotImplementOptionalSelector:(SEL)aSel;

@end
