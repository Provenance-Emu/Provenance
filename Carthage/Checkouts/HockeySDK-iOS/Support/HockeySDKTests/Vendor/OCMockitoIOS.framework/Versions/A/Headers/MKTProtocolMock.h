//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import "MKTBaseMockObject.h"


/*!
 * @abstract Mock object implementing a given protocol.
 */
@interface MKTProtocolMock : MKTBaseMockObject

@property (nonatomic, strong, readonly) Protocol *mockedProtocol;

- (instancetype)initWithProtocol:(Protocol *)aProtocol
          includeOptionalMethods:(BOOL)includeOptionalMethods;

@end
