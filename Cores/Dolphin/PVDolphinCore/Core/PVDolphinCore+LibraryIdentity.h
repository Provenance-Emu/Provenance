#pragma once
#import "PVDolphinCore.h"

@protocol PVLibraryDiscIdentityReading;

NS_ASSUME_NONNULL_BEGIN

/// Read-only metadata from a newly opened volume, independent of the running core.
@interface PVDolphinCoreBridge (LibraryIdentity) <PVLibraryDiscIdentityReading>
+ (nullable NSDictionary<NSString *, id> *)libraryDiscIdentityAtPath:(NSString *)path
                                                            error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSDictionary<NSString *, id> *)libraryIdentityAtPath:(NSString *)path
    NS_SWIFT_NAME(libraryIdentity(atPath:));
@end

NS_ASSUME_NONNULL_END
