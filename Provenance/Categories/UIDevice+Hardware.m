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

@end
