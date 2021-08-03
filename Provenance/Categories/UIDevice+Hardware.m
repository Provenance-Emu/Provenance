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
+ (BOOL)hasTapticMotor
{
    static BOOL hasTapticMotor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSInteger supportLevel = ((NSNumber *) [UIDevice.currentDevice valueForKey:@"_feedbackSupportLevel"]).integerValue;
        NSInteger iPhoneVersionNumber = [[UIDevice.currentDevice.modelIdentifier componentsSeparatedByString:@","].firstObject stringByReplacingOccurrencesOfString:@"iPhone" withString:@""].integerValue;
        if (iPhoneVersionNumber >= 9 || supportLevel == 2) { // 9 is iPhone 7
            hasTapticMotor = YES;
        }
        else {
            hasTapticMotor = NO;
        }
    });

    return hasTapticMotor;
}

@end
