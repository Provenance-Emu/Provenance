//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCIsAnything.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches anything, capturing all values.
 * @discussion This matcher captures all values it was given to match, and always evaluates to
 * <code>YES</code>. Use it to capture argument values for further assertions.
 *
 * Unlike other matchers, this matcher is not idempotent. It should be created outside of any
 * expression so that it can be queried for the items it captured.
 */
@interface HCArgumentCaptor : HCIsAnything

/*!
 * @abstract Returns the captured value.
 * @discussion If <code>-matches:</code> was called more than once then this property returns the
 * last captured value.
 *
 * If <code>-matches:</code> was never invoked and so no value was captured, this property returns
 * <code>nil</code>. But if <code>nil</code> was captured, this property returns NSNull.
 */
@property (nullable, nonatomic, readonly) id value;

/*!
 * @abstract Returns all captured values.
 * @discussion Returns an array containing all captured values, in the order in which they were
 * captured. <code>nil</code> values are converted to NSNull.
 */
@property (nonatomic, readonly) NSArray *allValues;

/*!
 * @abstract Determines whether subsequent matched values are captured.
 * @discussion <code>YES</code> by default.
 */
@property (nonatomic, assign) BOOL captureEnabled;

@end

NS_ASSUME_NONNULL_END
