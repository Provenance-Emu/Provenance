//
//  BITStoreUpdateManagerTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 13.03.13.
//
//

#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITStoreUpdateManager.h"
#import "BITStoreUpdateManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITTestHelper.h"


@interface BITStoreUpdateManagerTests : XCTestCase

@property(nonatomic, strong) BITStoreUpdateManager *storeUpdateManager;

@end


@implementation BITStoreUpdateManagerTests

- (void)setUp {
  [super setUp];
  
  // Set-up code here.
  self.storeUpdateManager = [[BITStoreUpdateManager alloc] initWithAppIdentifier:nil appEnvironment:BITEnvironmentAppStore];
}

- (void)tearDown {
  // Tear-down code here.
  self.storeUpdateManager = nil;
  
  [super tearDown];
}


#pragma mark - Private

- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  if (!dataString) return nil;
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
  return json;
}

- (void)startManager {
  self.storeUpdateManager.enableStoreUpdateManager = YES;
  [self.storeUpdateManager startManager];
  [NSObject cancelPreviousPerformRequestsWithTarget:self.storeUpdateManager selector:@selector(checkForUpdateDelayed) object:nil];
}


#pragma mark - Time

- (void)testUpdateCheckDailyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking daily first time ever");
}

- (void)testUpdateCheckDailyFirstTimeTodayLastCheckPreviousDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24)]];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckDaily;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking daily first time today with last check done previous day");
}

- (void)testUpdateCheckDailySecondTimeOfTheDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.lastCheck = [NSDate date];
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking daily second time of the day");
}

- (void)testUpdateCheckWeeklyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking weekly first time ever");
}

- (void)testUpdateCheckWeeklyFirstTimeTodayLastCheckPreviousWeek {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24*7)]];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertTrue(result, @"Checking weekly first time after one week");
}

- (void)testUpdateCheckWeeklyFirstTimeFiveDaysAfterPreviousCheck {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24*5)]];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckWeekly;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking weekly first time five days after previous check");
}

- (void)testUpdateCheckManuallyFirstTimeEver {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckManually;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking manually first time ever");
}

- (void)testUpdateCheckManuallyFirstTimeTodayLastCheckDonePreviousDay {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateDateOfLastCheck"]) willReturn:[NSDate dateWithTimeIntervalSinceNow:-(60*60*24)]];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  self.storeUpdateManager.updateSetting = BITStoreUpdateCheckManually;
  
  [self startManager];
  
  BOOL result = [self.storeUpdateManager shouldAutoCheckForUpdates];
  
  XCTAssertFalse(result, @"Checking manually first time ever");
}


#pragma mark - JSON Response Processing

- (void)testProcessStoreResponseWithEmptyData {
  BOOL result = [self.storeUpdateManager processStoreResponseWithString:nil];
  
  XCTAssertFalse(result, @"Empty data was handled correctly");
}

- (void)testProcessStoreResponseWithInvalidData {
  NSString *invalidString = @"8a@c&)if";
  BOOL result = [self.storeUpdateManager processStoreResponseWithString:invalidString];
  
  XCTAssertFalse(result, @"Invalid JSON data was handled correctly");
}

- (void)testProcessStoreResponseWithUnknownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierUnknown"];
  BOOL result = [self.storeUpdateManager processStoreResponseWithString:dataString];
  
  XCTAssertFalse(result, @"Valid but empty json data was handled correctly");
}

- (void)testProcessStoreResponseWithKnownBundleIdentifier {
  NSString *dataString = [BITTestHelper jsonFixture:@"StoreBundleIdentifierKnown"];
  BOOL result = [self.storeUpdateManager processStoreResponseWithString:dataString];

  XCTAssertTrue(result, @"Valid and correct JSON data was handled correctly");
}


#pragma mark - Last version

#pragma mark - Version compare

- (void)testFirstStartHasNewVersionReturnsFalseWithFirstCheck {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];

  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];

  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersion {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseWithSameVersionButDifferentUUID {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.2"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@"1"];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testFirstStartHasNewVersionReturnsTrue {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertTrue(result, @"There is an udpate available");
}


- (void)testFirstStartHasNewVersionReturnsFalseBecauseWeHaveANewerVersionInstalled {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.3"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"There is no udpate available");
}

- (void)testReportedVersionIsBeingIgnored {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateIgnoredVersion"]) willReturn:@"4.1.2"];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertFalse(result, @"The newer version is being ignored");
}

- (void)testReportedVersionIsNewerThanTheIgnoredVersion {
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastStoreVersion"]) willReturn:@"4.1.1"];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateLastUUID"]) willReturn:@""];
  [given([mockUserDefaults objectForKey:@"BITStoreUpdateIgnoredVersion"]) willReturn:@"4.1.1"];
  self.storeUpdateManager.userDefaults = mockUserDefaults;
  
  [self startManager];
  
  NSDictionary *json = [self jsonFromFixture:@"StoreBundleIdentifierKnown"];
  
  BOOL result = [self.storeUpdateManager hasNewVersion:json];
  
  XCTAssertTrue(result, @"The newer version is not ignored");
}

@end
