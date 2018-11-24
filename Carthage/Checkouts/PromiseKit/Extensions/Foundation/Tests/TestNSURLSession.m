@import PMKFoundation;
@import OHHTTPStubs;
@import Foundation;
@import PromiseKit;
@import XCTest;

@implementation NSURLSessionTests: XCTestCase

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
}

- (void)test200 {
    id stubData = [NSData dataWithBytes:"a" length:1];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *rq){
        return [rq.URL.host isEqualToString:@"example.com"];
    } withStubResponse:^(NSURLRequest *request){
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{@"Content-Type": @"text/html"}];
    }];

    id ex = [self expectationWithDescription:@""];
    id rq = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com"]];

    [[NSURLSession sharedSession] promiseDataTaskWithRequest:rq].then(^{
        [ex fulfill];
    });

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testBadJSON {
    id stubData = [NSData dataWithBytes:"[a: 3]" length:1];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *rq){
        return [rq.URL.host isEqualToString:@"example.com"];
    } withStubResponse:^(NSURLRequest *request){
        return [OHHTTPStubsResponse responseWithData:stubData statusCode:200 headers:@{@"Content-Type": @"application/json"}];
    }];

    id ex = [self expectationWithDescription:@""];
    id rq = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com"]];

    [[NSURLSession sharedSession] promiseDataTaskWithRequest:rq].catch(^(NSError *err){
        XCTAssertEqualObjects(err.domain, NSCocoaErrorDomain);  //TODO this is why we should replace this domain
        XCTAssertEqual(err.code, 3840);
        XCTAssertEqualObjects(err.userInfo[PMKURLErrorFailingDataKey], stubData);
        XCTAssertNotNil(err.userInfo[PMKURLErrorFailingURLResponseKey]);
        [ex fulfill];
    });

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

@end
