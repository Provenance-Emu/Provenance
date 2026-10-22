#import <Foundation/Foundation.h>
#import "PVCoreBridge-Swift.h"
NS_ASSUME_NONNULL_BEGIN
@interface PVDolphinCoreBridge: NSObject <PVLibraryDiscIdentityReading>
+ (nullable NSDictionary<NSString *, id> *)libraryIdentityAtPath:(NSString *)path
    NS_SWIFT_NAME(libraryIdentity(atPath:));
@end
NS_ASSUME_NONNULL_END
