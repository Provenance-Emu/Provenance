/*
 *
 * Modified BSD license.
 *
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */


#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "LoggerConstModel.h"

@class LoggerMessageCell;

@interface LoggerMessageData : NSManagedObject

@property (nonatomic, retain) NSNumber * clientHash;
@property (nonatomic, retain) NSNumber * contentsType;
@property (nonatomic, retain) NSString * dataFilepath;
@property (nonatomic, retain) NSString * filename;
@property (nonatomic, retain) NSString * fileFuncRepresentation;
@property (nonatomic, retain) NSString * functionName;
@property (nonatomic, retain) NSString * imageSize;
@property (nonatomic, retain) NSNumber * landscapeFileFuncHeight;
@property (nonatomic, retain) NSNumber * landscapeHeight;
@property (nonatomic, retain) NSNumber * landscapeHintHeight;
@property (nonatomic, retain) NSString * landscapeMessageSize;
@property (nonatomic, retain) NSNumber * level;
@property (nonatomic, retain) NSNumber * lineNumber;
@property (nonatomic, retain) NSString * messageText;
@property (nonatomic, retain) NSString * messageType;
@property (nonatomic, retain) NSNumber * portraitFileFuncHeight;
@property (nonatomic, retain) NSNumber * portraitHeight;
@property (nonatomic, retain) NSNumber * portraitHintHeight;
@property (nonatomic, retain) NSString * portraitMessageSize;
@property (nonatomic, retain) NSNumber * runCount;
@property (nonatomic, retain) NSNumber * sequence;
@property (nonatomic, retain) NSString * tag;
@property (nonatomic, retain) NSString * textRepresentation;
@property (nonatomic, retain) NSString * threadID;
@property (nonatomic, retain) NSNumber * timestamp;
@property (nonatomic, retain) NSString * timestampString;
@property (nonatomic, retain) NSNumber * truncated;
@property (nonatomic, retain) NSNumber * type;

-(LoggerMessageType)dataType;
-(void)imageForCell:(LoggerMessageCell *)aCell;
-(void)cancelImageForCell:(LoggerMessageCell *)aCell;
-(unsigned long)rawDataSize;
@end
