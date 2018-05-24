//
//  NSEvent+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSEvent+BWAdditions.h"

@implementation NSEvent (BWAdditions)

+ (BOOL)bwShiftKeyIsDown
{
	if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
		return YES;
	
	return NO;
}

+ (BOOL)bwCommandKeyIsDown
{
	if ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask)
		return YES;
	
	return NO;
}

+ (BOOL)bwOptionKeyIsDown
{
	if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
		return YES;
	
	return NO;
}

+ (BOOL)bwControlKeyIsDown
{
	if ([[NSApp currentEvent] modifierFlags] & NSControlKeyMask)
		return YES;
	
	return NO;
}

+ (BOOL)bwCapsLockKeyIsDown
{
	if ([[NSApp currentEvent] modifierFlags] & NSAlphaShiftKeyMask)
		return YES;
	
	return NO;
}

@end
