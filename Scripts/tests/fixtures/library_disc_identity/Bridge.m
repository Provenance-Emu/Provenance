#import "Bridge.h"
@implementation PVDolphinCoreBridge
+ (NSDictionary<NSString *, id> *)libraryIdentityAtPath:(NSString *)path {
    return [path isEqualToString:@"/disc two.rvz"] ?
        @{@"gameID": @"GTEST1", @"discNumber": @1, @"revision": @7} : nil;
}
@end
