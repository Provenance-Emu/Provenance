//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCBaseDescription.h>

@protocol HCSelfDescribing;


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract An HCDescription that is stored as a string.
 */
@interface HCStringDescription : HCBaseDescription
{
    NSMutableString *accumulator;
}

/*!
 * @abstract Returns the description of an HCSelfDescribing object as a string.
 * @param selfDescribing The object to be described.
 * @return The description of the object.
 */
+ (NSString *)stringFrom:(id <HCSelfDescribing>)selfDescribing;

/*!
 * @abstract Creates and returns an empty description.
 */
+ (instancetype)stringDescription;

/*!
 * @abstract Initializes a newly allocated HCStringDescription that is initially empty.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
