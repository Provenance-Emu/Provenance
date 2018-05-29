/*
 * LoggerUtils.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
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
#import "LoggerUtils.h"

NSString *StringWithTimeDelta(struct timeval *td)
{
	if (td->tv_sec)
	{
		NSInteger hrs,mn,s,ms;
		hrs = td->tv_sec / 3600;
		mn = (td->tv_sec % 3600) / 60;
		s = td->tv_sec % 60;
		ms = td->tv_usec / 1000;
		if (hrs != 0)
			return [NSString stringWithFormat:@"+%ldh %ldmn %ld.%03lds", hrs, mn, s, ms];
		if (mn != 0)
			return [NSString stringWithFormat:@"+%ldmn %ld.%03lds", mn, s, ms];
		if (s != 0)
		{
			if (ms != 0)
				return [NSString stringWithFormat:@"+%ld.%03lds", s, ms];
			return [NSString stringWithFormat:@"+%lds", s];
		}
	}
	if (td->tv_usec == 0)
		return @"";

	// millisecond resolution
	if (td->tv_usec > 10 || (td->tv_usec % 1000) == 0)
		return [NSString stringWithFormat:@"+%dms", td->tv_usec / 1000];

	// microsecond resolution
	return [NSString stringWithFormat:@"+%d.%03dms", td->tv_usec / 1000, td->tv_usec % 1000];
}


CGColorRef CreateCGColorFromUIColor(UIColor * color)
{
    CGFloat colorComponent[4] = {0.f, 0.f, 0.f, 0.f};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef colorRef = NULL;

    [color
     getRed:&(colorComponent[0])
     green:&(colorComponent[1])
     blue:&(colorComponent[2])
     alpha:&(colorComponent[3])];
    
    colorRef = CGColorCreate(colorSpace, colorComponent);
    CGColorSpaceRelease(colorSpace);

    return colorRef;
}

void MakeRoundedPath(CGContextRef ctx, CGRect r, CGFloat radius)
{
	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, CGRectGetMinX(r), CGRectGetMidY(r));
	CGContextAddArcToPoint(ctx, CGRectGetMinX(r), CGRectGetMinY(r), CGRectGetMidX(r), CGRectGetMinY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(r), CGRectGetMinY(r), CGRectGetMaxX(r), CGRectGetMidY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMaxX(r), CGRectGetMaxY(r), CGRectGetMidX(r), CGRectGetMaxY(r), radius);
	CGContextAddArcToPoint(ctx, CGRectGetMinX(r), CGRectGetMaxY(r), CGRectGetMinX(r), CGRectGetMidY(r), radius);
	CGContextClosePath(ctx);
}

