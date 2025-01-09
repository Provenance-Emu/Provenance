//
//  IsPasswordProtectedTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "URKArchiveTestCase.h"

@interface IsPasswordProtectedTests : URKArchiveTestCase

@end

@implementation IsPasswordProtectedTests

- (void)testIsPasswordProtected_PasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertTrue(archive.isPasswordProtected, @"isPasswordProtected = NO for password-protected archive");
}

- (void)testIsPasswordProtected_PasswordRequired_RAR5
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (RAR5, Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertTrue(archive.isPasswordProtected, @"isPasswordProtected = NO for password-protected RAR5 archive");
}

- (void)testIsPasswordProtected_HeaderPasswordRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive (Header Password).rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertTrue(archive.isPasswordProtected, @"isPasswordProtected = NO for password-protected archive");
}

- (void)testIsPasswordProtected_PasswordNotRequired
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    XCTAssertFalse(archive.isPasswordProtected, @"isPasswordProtected = YES for password-protected archive");
}

@end
