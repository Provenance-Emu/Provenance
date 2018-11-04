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



#import "LoggerDataEntry.h"
#import "NullStringCheck.h"

@interface LoggerDataEntry()
static void _split_dir_only(char**, const char*);
@end

@implementation LoggerDataEntry
{
	LoggerMessageType				_dataType;
	NSString						*_filepath;
	char							*_fpath_dir_part;
	NSString						*_dirOfFilepath;
	NSMutableArray					*_dataOperations;
	NSData							*_data;
}
@synthesize dataType = _dataType;
@synthesize filepath = _filepath;
@synthesize dirOfFilepath = _dirOfFilepath;
@synthesize dataOperations = _dataOperations;
@synthesize data = _data;

// This function come from ephemient of stackoverflow
//http://stackoverflow.com/questions/1575278/function-to-split-a-filepath-into-path-and-file/1575314#1575314
void
_split_dir_only(char** p, const char *pf)
{
    char *slash = (char *)pf, *next;
    while ((next = strpbrk(slash + 1, "\\/"))) slash = next;
    if (pf != slash) slash++;
    *p = strndup(pf, slash - pf);
}

-(id)initWithFilepath:(NSString *)aFilepath type:(LoggerMessageType)aType
{
	self = [super init];

	if(self)
	{
		_dataType = aType;
		
		// should never pass a null string
		assert(!IS_NULL_STRING(aFilepath));

		_filepath = [aFilepath retain];
		
		// split diretory part from file path
		_fpath_dir_part = NULL;
		_split_dir_only(&_fpath_dir_part,[aFilepath UTF8String]);
		
		// this is an error. should never happpen
		assert(_fpath_dir_part != NULL);
		
		// in case when you want to write a file at basepath...
		if(strlen(_fpath_dir_part) == 0)
		{
			//clean up and proceed
			free(_fpath_dir_part),_fpath_dir_part = NULL;
			_dirOfFilepath = nil;
		}
		// we have proper dir part of filepath now.
		else
		{
			_dirOfFilepath = \
				[[NSString alloc]
				 initWithBytesNoCopy:_fpath_dir_part
				 length:strlen(_fpath_dir_part)
				 encoding:NSASCIIStringEncoding
				 freeWhenDone:NO];
		}
		
		_dataOperations = [[NSMutableArray alloc] initWithCapacity:0];

	}
	return self;
}

-(void)dealloc
{
	[_filepath release],_filepath = nil;

	if(_dirOfFilepath != nil)
	{
		[_dirOfFilepath release],_dirOfFilepath = nil;
	}

	if(_fpath_dir_part != NULL)
	{
		free(_fpath_dir_part),_fpath_dir_part = NULL;
	}

	[_dataOperations removeAllObjects];
	[_dataOperations release],_dataOperations = nil;
	
	if(_data != nil)
	{
		[_data release],_data = nil;
	}

	[super dealloc];
}

-(NSInteger)totalDataLength
{
	return ([_filepath length] + [_dirOfFilepath length] + [_data length]);
}

@end
