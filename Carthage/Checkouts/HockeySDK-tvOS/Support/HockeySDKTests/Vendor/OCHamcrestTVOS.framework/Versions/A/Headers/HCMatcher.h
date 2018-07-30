//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import "HCSelfDescribing.h"


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract A matcher over acceptable values.
 * @discussion A matcher is able to describe itself to give feedback when it fails.
 *
 * HCMatcher implementations should not directly implement this protocol. Instead, extend the
 * HCBaseMatcher class, which will ensure that the HCMatcher API can grow to support new features
 * and remain compatible with all HCMatcher implementations.
 */
@protocol HCMatcher <HCSelfDescribing>

/*!
 * @abstract Evaluates the matcher for argument item.
 * @param item  The object against which the matcher is evaluated.
 * @return <code>YES</code> if item matches, otherwise <code>NO</code>.
 */
- (BOOL)matches:(nullable id)item;

/*!
 * @abstract Evaluates the matcher for argument item.
 * @param item The object against which the matcher is evaluated.
 * @param mismatchDescription The description to be built or appended to if item does not match.
 * @return <code>YES</code> if item matches, otherwise <code>NO</code>.
 */
- (BOOL)matches:(nullable id)item describingMismatchTo:(nullable id <HCDescription>)mismatchDescription;

/*!
 * @abstract Generates a description of why the matcher has not accepted the item.
 * @param item The item that the HCMatcher has rejected.
 * @param mismatchDescription The description to be built or appended to.
 * @discussion The description will be part of a larger description of why a matching failed, so it
 * should be concise.
 *
 * This method assumes that <code>matches:item</code> is false, but will not check this.
 */
- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription;

@end

NS_ASSUME_NONNULL_END
