//
//  RARExtractException.h
//  Unrar4iOS
//
//  Created by Rogerio Araujo on 07/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum { RARArchiveProtected, RARArchiveInvalid, RARArchiveBadFormat } RARArchiveStatus;

@interface RARExtractException : NSException {

    RARArchiveStatus status;
    
}

@property (nonatomic, assign) RARArchiveStatus status;

/** Initialize the exception with a message.
 *
 * @param message The message.
 */
- (id)initWithStatus:(RARArchiveStatus)status;

/** Return an exception with the given message
 *
 * @param theMessage The user-friendly message
 */
+ (RARExtractException *)exceptionWithStatus:(RARArchiveStatus)status;

@end