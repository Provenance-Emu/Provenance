//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 Jonathan M. Reid. See LICENSE.txt

#import "MKTBaseMockObject.h"


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Mock object implementing a given protocol.
 */
@interface MKTProtocolMock : MKTBaseMockObject

@property (nonatomic, strong, readonly) Protocol *mockedProtocol;

- (instancetype)initWithProtocol:(Protocol *)aProtocol
          includeOptionalMethods:(BOOL)includeOptionalMethods NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
