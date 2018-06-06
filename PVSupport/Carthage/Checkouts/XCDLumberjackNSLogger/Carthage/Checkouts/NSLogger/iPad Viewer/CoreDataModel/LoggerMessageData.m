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



#import "LoggerMessageData.h"
#import "LoggerDataStorage.h"
#import "LoggerMessageCell.h"

@interface LoggerMessageData()
-(LoggerMessageCell *)messageCell;
-(void)setMessageCell:(LoggerMessageCell *)aCell;
@end

@implementation LoggerMessageData
{
	LoggerMessageCell		*_targetCell;
	BOOL					_isReadImageTriggered;
}
@dynamic clientHash;
@dynamic contentsType;
@dynamic dataFilepath;
@dynamic filename;
@dynamic functionName;
@dynamic fileFuncRepresentation;
@dynamic imageSize;
@dynamic landscapeFileFuncHeight;
@dynamic landscapeHeight;
@dynamic landscapeHintHeight;
@dynamic landscapeMessageSize;
@dynamic level;
@dynamic lineNumber;
@dynamic messageText;
@dynamic messageType;
@dynamic portraitFileFuncHeight;
@dynamic portraitHeight;
@dynamic portraitHintHeight;
@dynamic portraitMessageSize;
@dynamic runCount;
@dynamic sequence;
@dynamic tag;
@dynamic textRepresentation;
@dynamic threadID;
@dynamic timestamp;
@dynamic timestampString;
@dynamic truncated;
@dynamic type;

//@@TODO :: remove and have faith in the power of CoreData!!!
-(unsigned long)rawDataSize
{
	unsigned long size = 0;
	
	size += 4;// client hash
	size += 2;// contentsType
	size += [[self dataFilepath] length];
	size += [[self filename] length];
	size += [[self functionName] length];
	size += [[self fileFuncRepresentation] length];
	size += [[self imageSize] length];
	size += 4; // landscape height
	size += 4; // landscale hint
	size += [[self landscapeMessageSize] length];
	size += 4; // level
	size += 4; // line num
	size += [[self messageText] length];
	size += [[self messageType] length];
	size += 4; // portraight height
	size += 4; // portraight hint
	size += [[self portraitMessageSize] length];
	size += 4; // run count
	size += 4; // sequence
	size += 4; // tag
	size += [[self textRepresentation] length];
	size += [[self threadID] length];
	size += 8; // timestamp
	size += [[self timestampString] length];
	size += 4; // truncated
	size += 2; // type;
	
	return size;
}

-(LoggerMessageCell *)messageCell
{
	return _targetCell;
}

-(void)setMessageCell:(LoggerMessageCell *)aCell
{
	if(_targetCell != aCell)
	{
		[aCell retain];
		[_targetCell release],_targetCell = nil;
		_targetCell = aCell;
	}
}

-(void)didTurnIntoFault
{
	if(_targetCell != nil && !_isReadImageTriggered)
	{
		[_targetCell release],_targetCell = nil;
	}
	
	[super didTurnIntoFault];
}

-(void)dealloc
{
	if(_targetCell != nil && !_isReadImageTriggered)
	{
		[_targetCell release],_targetCell = nil;
	}
	
	[super dealloc];
}


-(LoggerMessageType)dataType
{
	LoggerMessageType type = (LoggerMessageType)[[self contentsType] shortValue];
	return type;
}


-(void)imageForCell:(LoggerMessageCell *)aCell
{
	
	LoggerMessageType type = [self dataType];
	
	//now store datas
	if(type != kMessageImage)
		return;
	
	[self setMessageCell:aCell];
	
	if(!_isReadImageTriggered)
	{
		_isReadImageTriggered = YES;
		
		[[LoggerDataStorage sharedDataStorage]
		 readDataFromPath:[self dataFilepath]
		 forType:type
		 withResult:^(NSData *aData) {
			 dispatch_async(dispatch_get_main_queue(), ^{
				 
				 if(aData != nil && [aData length])
				 {
					 [[self messageCell] setImagedata:aData forRect:CGRectZero];
				 }
				 // release the cell after use
				 [self setMessageCell:nil];
				 _isReadImageTriggered = NO;
			 });
		 }];
	}
}

-(void)cancelImageForCell:(LoggerMessageCell *)aCell
{
	LoggerMessageType type = [self dataType];
	
	//now store datas
	if(type != kMessageImage)
		return;
	
	[self setMessageCell:nil];
}

@end
