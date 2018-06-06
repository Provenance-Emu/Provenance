//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Base class for matchers that generate mismatch descriptions during the matching.
 * @discussion Some matching algorithms have several "no match" paths. It helps to make the mismatch
 * description as precise as possible, but we don't want to have to repeat the matching logic to do
 * so. For such matchers, subclass HCDiagnosingMatcher and implement HCMatcher's
 * <code>-matches:describingMismatchTo:</code>.
*/
@interface HCDiagnosingMatcher : HCBaseMatcher
@end

NS_ASSUME_NONNULL_END
