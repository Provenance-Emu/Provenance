#import <XCTest/XCTest.h>
#import "BITEventData.h"
#import "BITOrderedDictionary.h"

@interface BITEventDataTests : XCTestCase

@end

@implementation BITEventDataTests

- (void)testverPropertyWorksAsExpected {
  NSNumber *expected = @42;
  BITEventData *item = [BITEventData new];
  item.version = expected;
  NSNumber *actual = item.version;
  XCTAssertTrue([actual isEqual:expected]);
  
  expected = @13;
  item.version = expected;
  actual = item.version;
  XCTAssertTrue([actual isEqual:expected]);
}

- (void)testnamePropertyWorksAsExpected {
  NSString *expected = @"Test string";
  BITEventData *item = [BITEventData new];
  item.name = expected;
  NSString *actual = item.name;
  XCTAssertTrue([actual isEqualToString:expected]);
  
  expected = @"Other string";
  item.name = expected;
  actual = item.name;
  XCTAssertTrue([actual isEqualToString:expected]);
}

- (void)testSerialize {
  BITEventData *item = [BITEventData new];
  item.version = @42;
  item.name = @"Test string";
  item.properties = @{@"propA":@"valueA"};
  item.measurements = @{@"measA": @2};
  
  NSDictionary *actual = [item serializeToDictionary];
  NSDictionary *expected = @{@"properties":item.properties, @"measurements":item.measurements, @"name":item.name, @"ver":item.version};
  XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
