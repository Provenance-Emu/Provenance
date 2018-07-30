//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>
#import <OCHamcrestTVOS/HCDescription.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Base class for all HCDescription implementations.
 */
@interface HCBaseDescription : NSObject <HCDescription>
@end


/*!
 * @abstract Methods that must be provided by subclasses of HCBaseDescription.
 */
@interface HCBaseDescription (SubclassResponsibility)

/*!
 * @abstract Appends the specified string to the description.
 */
- (void)append:(NSString *)str;

@end

NS_ASSUME_NONNULL_END
