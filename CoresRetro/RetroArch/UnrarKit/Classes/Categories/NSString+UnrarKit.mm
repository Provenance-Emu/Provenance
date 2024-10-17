//
//  NSString+UnrarKit.m
//  UnrarKit
//
//

#import "NSString+UnrarKit.h"
#import "UnrarKitMacros.h"

RarHppIgnore
#import "rar.hpp"
#pragma clang diagnostic pop

@implementation NSString (UnrarKit)

+ (instancetype)stringWithUnichars:(wchar_t *)unichars {
    return [[NSString alloc] initWithBytes:unichars
                                    length:wcslen(unichars) * sizeof(*unichars)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}

@end
