//
//  NSObject+PVAbstractAdditions.m
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "NSObject+PVAbstractAdditions.h"
#import "PVLogging.h"

@implementation NSObject (PVAbstractAdditions)

+ (void)doesNotImplementSelector:(SEL)aSel
{
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"*** +%s cannot be sent to the abstract class %@: Create a concrete subclass!", sel_getName(aSel), [self class]]
                                 userInfo:nil];
}

- (void)doesNotImplementSelector:(SEL)aSel
{
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"*** -%s cannot be sent to an abstract object of class %@: Create a concrete instance!", sel_getName(aSel), [self class]]
                                 userInfo:nil];
}

+ (void)doesNotImplementOptionalSelector:(SEL)aSel
{
    ELOG(@"*** +%s is an optional method and it is not implemented in %@!", sel_getName(aSel), NSStringFromClass([self class]));
}

- (void)doesNotImplementOptionalSelector:(SEL)aSel
{
    ELOG(@"*** -%s is an optional method and it is not implemented in %@!", sel_getName(aSel), NSStringFromClass([self class]));
}


@end
