//
//  ValidatePasswordTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "URKArchiveTestCase.h"

@interface ValidatePasswordTests : URKArchiveTestCase @end

@implementation ValidatePasswordTests

- (void)testValidatePassword_PasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when no password supplied");
    
    archive.password = @"wrong";
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when wrong password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when correct password supplied");
}

- (void)testValidatePassword_HeaderPasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Header Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when no password supplied");
    
    archive.password = @"wrong";
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when wrong password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when correct password supplied");
}

- (void)testValidatePassword_PasswordNotRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when no password supplied");
    
    archive.password = @"password";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when password supplied");
}

- (void)testValidatePassword_RAR5
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (RAR5, Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when no password supplied");
    
    archive.password = @"wrong";
    XCTAssertFalse(archive.validatePassword, @"validatePassword = YES when wrong password supplied");
    
    archive.password = @"123";
    XCTAssertTrue(archive.validatePassword, @"validatePassword = NO when correct password supplied");
}


@end
