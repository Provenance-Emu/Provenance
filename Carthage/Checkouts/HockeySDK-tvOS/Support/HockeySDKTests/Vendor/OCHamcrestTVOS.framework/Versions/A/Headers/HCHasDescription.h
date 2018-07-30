//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCInvocationMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches objects whose description satisfies a nested matcher.
 */
@interface HCHasDescription : HCInvocationMatcher

- (instancetype)initWithDescription:(id <HCMatcher>)descriptionMatcher NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithInvocation:(NSInvocation *)anInvocation matching:(id <HCMatcher>)aMatcher NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_hasDescription(id descriptionMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object's <code>-description</code>
 * satisfies the specified matcher.
 * @param descriptionMatcher The matcher used to verify the description result, or an expected value
 * for <em>equalTo</em> matching.
 * @discussion If <em>descriptionMatcher</em> is not a matcher, it is implicitly wrapped in
 * an <em>equalTo</em> matcher to check for equality.
 *
 * <b>Examples</b><br />
 * <pre>assertThat(myObject, hasDescription(equalTo(\@"foo"))</pre>
 * <pre>assertThat(myObject, hasDescription(\@"foo"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_hasDescription instead.
 */
static inline id hasDescription(id descriptionMatcher)
{
    return HC_hasDescription(descriptionMatcher);
}
#endif

NS_ASSUME_NONNULL_END
