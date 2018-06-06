//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCDiagnosingMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Does executing a block throw an exception which satisfies a nested matcher?
 */
@interface HCThrowsException : HCDiagnosingMatcher

- (id)initWithExceptionMatcher:(id)exceptionMatcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_throwsException(id exceptionMatcher);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is a block which, when
 * executed, throws an exception satisfying the specified matcher.
 * @param exceptionMatcher The matcher to satisfy when passed the exception.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(^{ [obj somethingBad]; }, throwsException(hasProperty(@"reason", @"EXPECTED REASON")))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_throwsException instead.
 */
static inline id throwsException(id exceptionMatcher)
{
    return HC_throwsException(exceptionMatcher);
}
#endif

NS_ASSUME_NONNULL_END
