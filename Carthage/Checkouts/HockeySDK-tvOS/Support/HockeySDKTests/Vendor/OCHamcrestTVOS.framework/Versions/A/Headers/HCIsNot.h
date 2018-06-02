//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Calculates the logical negation of a matcher.
 */
@interface HCIsNot : HCBaseMatcher

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_isNot(_Nullable id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that wraps an existing matcher, but inverts the logic by which it
 * will match.
 * @param value The matcher to negate, or an expected value to match for inequality.
 * @discussion If <em>value</em> is not a matcher, it is implicitly wrapped in an <em>equalTo</em>
 * matcher to check for equality, and thus matches for inequality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(cheese, isNot(equalTo(smelly)))</pre>
 * <pre>assertThat(cheese, isNot(smelly))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isNot instead.
 */
static inline id isNot(_Nullable id value)
{
    return HC_isNot(value);
}
#endif

NS_ASSUME_NONNULL_END
