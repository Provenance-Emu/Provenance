//
//  RARExtractException.m
//  Unrar4iOS
//
//  Created by Rogerio Araujo on 07/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RARExtractException.h"

@implementation RARExtractException

@synthesize status;

- (id)initWithStatus:(RARArchiveStatus)aStatus {
    
    self = [super initWithName:@"RARExtractException" reason:nil userInfo:nil];
    if (self) {
        self.status = aStatus;
    }
    
    return self;
}

+ (RARExtractException *) exceptionWithStatus:(RARArchiveStatus)aStatus {
    
    return [[RARExtractException alloc] initWithStatus:aStatus];
}

@end