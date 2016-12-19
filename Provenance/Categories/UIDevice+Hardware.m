//
//  UIDevice+Hardware.m
//  Provenance
//
//  Created by James Addyman on 24/09/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "UIDevice+Hardware.h"
#include <sys/sysctl.h>

@implementation UIDevice (Hardware)

- (NSString *)getSysInfoByName:(char *)typeSpecifier
{
	size_t size;
	sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);

	char *answer = malloc(size);
	sysctlbyname(typeSpecifier, answer, &size, NULL, 0);

	NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];

	free(answer);
	return results;
}

- (NSString *)modelIdentifier
{
	return [self getSysInfoByName:"hw.machine"];
}

///All known Device Types for iPhone 7 or iPhone 7 Plus
+ (BOOL)isIphone7or7Plus
{
    if ([[[UIDevice currentDevice] modelIdentifier] isEqualToString:@"iPhone9,1"] ||    //iPhone 7 (A1660/A1779/A1780)
        [[[UIDevice currentDevice] modelIdentifier] isEqualToString:@"iPhone9,2"] ||    //iPhone 7 Plus (A1661/A1785/A1786)
        [[[UIDevice currentDevice] modelIdentifier] isEqualToString:@"iPhone9,3"] ||    //iPhone 7 (A1778)
        [[[UIDevice currentDevice] modelIdentifier] isEqualToString:@"iPhone9,4"]) {    //iPhone 7 Plus (A1784)
        
        return YES;
    }
    else {
        return NO;
    }
}

@end
