//
//  TopShelfLoader.m
//  TopShelfv2
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <os/log.h>

// This Objective-C file will be loaded by the Objective-C runtime
// even if Swift code isn't properly initialized

__attribute__((constructor))
static void TopShelfLoaderInitialize(void) {
    // This function will be called when the extension is loaded
    os_log_t logger = os_log_create("org.provenance-emu.provenance.topshelf", "Loader");
    os_log_info(logger, "TopShelf extension is being loaded");
    
    // Try to write to a file in the shared container
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // Get the app group identifier from the Info.plist
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *appGroupID = [bundle objectForInfoDictionaryKey:@"APP_GROUP_IDENTIFIER"];
    if (!appGroupID) {
        appGroupID = @"group.org.provenance-emu.provenance";
    }
    os_log_info(logger, "Using app group ID: %{public}@", appGroupID);
    
    NSURL *containerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:appGroupID];
    
    if (containerURL) {
        NSURL *logFileURL = [containerURL URLByAppendingPathComponent:@"topshelf_objc_log.txt"];
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                             dateStyle:NSDateFormatterShortStyle
                                                             timeStyle:NSDateFormatterFullStyle];
        NSString *logMessage = [NSString stringWithFormat:@"TopShelf Objective-C loader initialized at %@\n", timestamp];
        
        NSError *error = nil;
        if ([fileManager fileExistsAtPath:[logFileURL path]]) {
            // Append to existing file
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:logFileURL error:&error];
            if (fileHandle) {
                [fileHandle seekToEndOfFile];
                [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
                [fileHandle closeFile];
                os_log_info(logger, "Wrote to log file at %{public}@", [logFileURL path]);
            } else {
                os_log_error(logger, "Failed to open log file: %{public}@", [error localizedDescription]);
            }
        } else {
            // Create new file
            [logMessage writeToURL:logFileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                os_log_error(logger, "Failed to create log file: %{public}@", [error localizedDescription]);
            } else {
                os_log_info(logger, "Created log file at %{public}@", [logFileURL path]);
            }
        }
    } else {
        os_log_error(logger, "Could not access app group container");
    }
}
