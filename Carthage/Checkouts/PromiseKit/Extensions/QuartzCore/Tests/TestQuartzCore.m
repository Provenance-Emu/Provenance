@import PMKQuartzCore;
@import PromiseKit;
@import QuartzCore;
@import XCTest;

@implementation TestCALayer: XCTestCase

- (void)test {
    id ex = [self expectationWithDescription:@""];

    [[CALayer layer] promiseAnimation:[CAAnimation new] forKey:@"center"].then(^{
        [ex fulfill];
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
