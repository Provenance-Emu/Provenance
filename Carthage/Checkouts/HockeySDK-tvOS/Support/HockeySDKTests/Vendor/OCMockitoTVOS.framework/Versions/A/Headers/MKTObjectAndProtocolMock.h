//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 Jonathan M. Reid. See LICENSE.txt
//  Contribution by Kevin Lundberg

#import "MKTProtocolMock.h"


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Mock object of a given class that also implements a given protocol.
 */
@interface MKTObjectAndProtocolMock : MKTProtocolMock

- (instancetype)initWithClass:(Class)aClass protocol:(Protocol *)protocol NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithProtocol:(Protocol *)aProtocol
          includeOptionalMethods:(BOOL)includeOptionalMethods NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
