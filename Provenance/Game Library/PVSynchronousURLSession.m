//
//  PVSynchronousURLSession.m
//  Provenance
//
//  Created by James Addyman on 26/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVSynchronousURLSession.h"

@implementation PVSynchronousURLSession

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(__autoreleasing NSURLResponse **)responsePtr
                             error:(__autoreleasing NSError **)errorPtr
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData * result = nil;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (errorPtr != NULL) {
                                             *errorPtr = error;
                                         }
                                         if (responsePtr != NULL) {
                                             *responsePtr = response;
                                         }
                                         if (error == nil) {
                                             result = data;
                                         }
                                         dispatch_semaphore_signal(sem);
                                     }] resume];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

@end
