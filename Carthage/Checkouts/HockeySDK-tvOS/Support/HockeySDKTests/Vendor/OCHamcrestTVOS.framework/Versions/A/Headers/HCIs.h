//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Decorates another matcher.
 */
@interface HCIs : HCBaseMatcher

- (instancetype)initWithMatcher:(id <HCMatcher>)matcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_is(_Nullable id value);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Wraps an existing matcher, or provides a shortcut to the frequently
 * used <code>is(equalTo(x))</code>.
 * @param value The matcher to satisfy, or an expected value for <em>equalTo</em> matching.
 * @discussion
 * If <em>value</em>is a matcher, its behavior is retained, but the test may be slightly more
 * expressive. For example:
 * <ul>
 *   <li><code>assertThat(\@(value), equalTo(\@5))</code></li>
 *   <li><code>assertThat(\@(value), is(equalTo(\@5)))</code></li>
 * </ul>
 *
 * If <em>value</em>is not a matcher, it is wrapped in an <em>equalTo</em> matcher. This makes the
 * following statements equivalent:
 * <ul>
 *   <li><code>assertThat(cheese, equalTo(smelly))</code></li>
 *   <li><code>assertThat(cheese, is(equalTo(smelly)))</code></li>
 *   <li><code>assertThat(cheese, is(smelly))</code></li>
 * </ul>
 *
 * Choose the style that makes your expression most readable. This will vary depending on context.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_is instead.
 */
static inline id is(_Nullable id value)
{
    return HC_is(value);
}
#endif

NS_ASSUME_NONNULL_END
