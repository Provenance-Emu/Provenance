#import <XCTest/XCTest.h>

#import <OCHamcrestTVOS/OCHamcrestTVOS.h>
#import <OCMockitoTVOS/OCMockitoTVOS.h>

@interface BITTestsDependencyInjection : XCTestCase

- (void)setMockNotificationCenter:(id)mockNotificationCenter;
- (id)mockNotificationCenter;

@end
