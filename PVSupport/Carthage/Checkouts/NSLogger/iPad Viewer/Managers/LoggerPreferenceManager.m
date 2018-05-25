/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 2010-2012 Florent Pillet,
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



#import "LoggerPreferenceManager.h"
#import "SynthesizeSingleton.h"

@implementation LoggerPreferenceManager
@synthesize shouldPublishBonjourService;
@synthesize hasDirectTCPIPResponder;
@synthesize directTCPIPResponderPort;
@synthesize bonjourServiceName;

SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(LoggerPreferenceManager,sharedPrefManager);

NSString * const kBonjourServiceName = @"NSLogger iPad";

-(BOOL)shouldPublishBonjourService
{
	return YES;
}

-(BOOL)hasDirectTCPIPResponder
{
	return YES;
}

-(NSInteger)directTCPIPResponderPort
{
	return 5000;
}

-(NSString*)bonjourServiceName
{
	//return @"NSLogger iPad";
	return kBonjourServiceName;
}


@end
