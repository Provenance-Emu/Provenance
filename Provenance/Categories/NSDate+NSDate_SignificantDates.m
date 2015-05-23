//
//  NSDate+NSDate_SignificantDates.m
//  Provenance
//
//  Created by James Addyman on 11/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "NSDate+NSDate_SignificantDates.h"

@implementation NSDate (NSDate_SignificantDates)

+ (NSDate *)macAnnouncementDate
{
    // 1984-01-24 08:00:0
    return [NSDate dateWithTimeIntervalSince1970:443779200.0];
}

@end
