//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@protocol HCMatcher;


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Wraps argument in a matcher, if necessary.
 * @return The argument as-is if it is already a matcher, otherwise wrapped in an <em>equalTo</em> matcher.
 */
FOUNDATION_EXPORT _Nullable id <HCMatcher> HCWrapInMatcher(_Nullable id matcherOrValue);

NS_ASSUME_NONNULL_END
