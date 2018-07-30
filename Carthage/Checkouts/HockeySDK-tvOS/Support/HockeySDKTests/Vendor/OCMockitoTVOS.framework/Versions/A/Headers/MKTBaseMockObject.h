//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>
#import "MKTNonObjectArgumentMatching.h"


NS_ASSUME_NONNULL_BEGIN

@interface MKTBaseMockObject : NSProxy <MKTNonObjectArgumentMatching>

+ (BOOL)isMockObject:(id)object;

- (instancetype)init;
- (void)stopMocking;

@end

NS_ASSUME_NONNULL_END
