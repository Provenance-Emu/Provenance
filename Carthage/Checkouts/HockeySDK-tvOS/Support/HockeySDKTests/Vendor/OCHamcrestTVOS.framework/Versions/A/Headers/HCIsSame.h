//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Is the value the same object as another value?
 */
@interface HCIsSame : HCBaseMatcher

- (instancetype)initSameAs:(nullable id)object NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_sameInstance(_Nullable id expectedInstance);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches only when the examined object is the same instance as
 * the specified target object.
 * @param expectedInstance The expected instance.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(delegate, sameInstance(expectedDelegate))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_sameInstance instead.
 */
static inline id sameInstance(_Nullable id expectedInstance)
{
    return HC_sameInstance(expectedInstance);
}
#endif

NS_ASSUME_NONNULL_END
