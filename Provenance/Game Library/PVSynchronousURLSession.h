//
//  PVSynchronousURLSession.h
//  Provenance
//
//  Created by James Addyman on 26/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PVSynchronousURLSession : NSObject

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(__autoreleasing NSURLResponse **)responsePtr
                             error:(__autoreleasing NSError **)errorPtr;

@end
