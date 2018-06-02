//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Tests if a string is equal to another string, regardless of the case.
 */
@interface HCIsEqualIgnoringCase : HCBaseMatcher

- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_equalToIgnoringCase(NSString *expectedString);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher for NSStrings that matches when the examined string is equal to the
 * specified expected string, ignoring case differences.
 * @param expectedString The expected value of matched strings. (Must not be <code>nil</code>.)
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"Foo", equalToIgnoringCase(\@"FOO"))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalToIgnoringCase instead.
 */
static inline id equalToIgnoringCase(NSString *expectedString)
{
    return HC_equalToIgnoringCase(expectedString);
}
#endif

NS_ASSUME_NONNULL_END
