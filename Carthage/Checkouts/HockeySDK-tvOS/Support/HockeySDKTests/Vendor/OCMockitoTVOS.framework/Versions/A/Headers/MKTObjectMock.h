//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 Jonathan M. Reid. See LICENSE.txt

#import "MKTBaseMockObject.h"


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Mock object of a given class.
 */
@interface MKTObjectMock : MKTBaseMockObject

- (instancetype)initWithClass:(Class)aClass NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
