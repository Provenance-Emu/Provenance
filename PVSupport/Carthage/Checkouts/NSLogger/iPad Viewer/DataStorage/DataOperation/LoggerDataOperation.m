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



#import "LoggerDataOperation.h"

@implementation LoggerDataOperation

@synthesize basepath = _basepath;
@synthesize filepath = _filepath;
@synthesize dirPartOfFilepath = _dirPartOfFilepath;
@synthesize absTargetFilePath = _absTargetFilePath;

@synthesize callback = _callback;
@synthesize queue_io_handler = _queue_io_handler;
@synthesize queue_callback = _queue_callback;
@synthesize executing = _executing;
@synthesize dependencyCount = _dependencyCount;


-(id)initWithBasepath:(NSString *)aBasepath
			 filePath:(NSString *)aFilepath
		dirOfFilepath:(NSString *)aDirOfFilepath
	   callback_queue:(dispatch_queue_t)a_callback_queue
			 callback:(callback_t)a_callback_block
{
	self = [super init];
	if(self)
	{
		_dependencyCount = 0;
		_executing = NO;

		_basepath = [aBasepath retain];
		_filepath = [aFilepath retain];
		_dirPartOfFilepath = [aDirOfFilepath retain];
		_absTargetFilePath = [[NSString alloc] initWithFormat:@"%@%@",aBasepath,aFilepath];

		/*
		 If multiple subsystems of your application share a dispatch object,
		 each subsystem should call dispatch_retain to register its interest
		 in the object. The object is deallocated only when all subsystems
		 have released their interest in the dispatch source.
		 */
		_queue_callback = a_callback_queue;
		dispatch_retain(_queue_callback);
		
		_callback = [a_callback_block copy];

		_queue_io_handler =\
			dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0);
	}
	return self;
}

-(void)dealloc
{
	[_basepath release],_basepath = nil;
	[_filepath release],_filepath = nil;
	[_dirPartOfFilepath release],_dirPartOfFilepath = nil;
	[_absTargetFilePath release],_absTargetFilePath = nil;
	dispatch_release(_queue_callback),_queue_callback = NULL;
	[_callback release], _callback = NULL;
	_queue_io_handler = NULL;
	[super dealloc];
}

-(void)executeOnQueue:(dispatch_queue_t)aQueue
{
	// subclass must implement this
}

@end
