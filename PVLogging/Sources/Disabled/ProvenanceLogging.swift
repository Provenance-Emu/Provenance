//
//  PVProvenanceLogging.swift
//  PVLogging
//
//  Created by Mattiello, Joseph R on 1/4/23.
//  Copyright (c) 2023 Joe Mattiello. All rights reserved.
//

import Foundation.NSPathUtilities
let LOGGING_STACK_SIZE = 1024

public final class ProvenanceLogging {
    public static let shared = ProvenanceLogging()
    fileprivate var history: [PVLogEntry] = []

    public var directoryForLogs: String {
        let s: NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        return s.appendingPathComponent("Logs")
    }

    public var logFilePaths: [String] {
        let docsDirectory = directoryForLogs
        do {
            let dirContents = try FileManager.default.contentsOfDirectory(atPath: docsDirectory)
            let logFiles = dirContents.filter { $0.hasSuffix(".pvlog") }
            return logFiles.map { docsDirectory + "/" + $0 }
        } catch {
            return []
        }
    }

    public var logFilename: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        return "PVLog-\(dateString).pv"
    }

    public var logFileInfos: [String]? {
        // TODO:
        return nil
    }

    public func flushLogs() {
        // TODO:
    }

    public func log(toFile path: String ...) {
        /*
        	va_list args;
	va_start(args, inString);
	NSString *expString = [[NSString alloc] initWithFormat:inString arguments:args];
	va_end(args);

        // DSwift - inject timestamp
    static NSDateFormatter *format = nil;
    if (! format) {
        format = [[NSDateFormatter alloc] init];
            //[format setDateFormat:@"yyyy'-'MM'-'dd"];
        [format setDateStyle:NSDateFormatterMediumStyle];
        [format setTimeStyle:NSDateFormatterMediumStyle];
    }
    NSString *timestamp = [format stringFromDate:[NSDate date]];
    NSString *finalString = [[NSString alloc] initWithFormat:@"%@ %@\r\n", timestamp, expString];

	NSData *dataToWrite = [finalString dataUsingEncoding:NSUTF8StringEncoding];

	NSString *docsDirectory = [self directoryForLogs];
	NSString *path = [docsDirectory stringByAppendingPathComponent:[self logFilename]];

	if (![[NSFileManager defaultManager] isWritableFileAtPath: path]) {
		[[NSFileManager defaultManager] createFileAtPath: path
												contents: [@"PVLOGGING STARTED\r\n" dataUsingEncoding: NSUTF8StringEncoding]
											  attributes: nil];
	}

	NSFileHandle* bmlogFile = [NSFileHandle fileHandleForWritingAtPath:path];
	[bmlogFile seekToEndOfFile];

        // Write the file
	[bmlogFile writeData: dataToWrite];

        // This is ineffecient, seeking and closing every write is slow. Keep
        // open, call close on app shutdown instead
    [bmlogFile closeFile];
    */
    }

    func validateLogDirectoryExists() {
        let docsDirectory = directoryForLogs
        if !FileManager.default.fileExists(atPath: docsDirectory) {
            do {
                try FileManager.default.createDirectory(atPath: docsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating log directory: \(error)")
            }
        }
    }

    public func add(historyEvent event: AnyObject) {
        if history.count >= LOGGING_STACK_SIZE {
            history.removeLast()
        }

        if let event = event as? PVLogEntry {
            history.insert(event, at: 0)
        } else {
            if let event = event as? String {
                history.insert(PVLogEntry(message: event), at: 0)
            } else {
                history.insert(PVLogEntry(message: "\(event)"), at: 0)
            }
        }
        PVLogging.shared.notifyListeners()
    }

    func deleteOldLogs() {
        /*
            NSArray *logFiles = [self logFilePaths];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *path in logFiles) {
        NSError *error;

        BOOL success =
        [fm removeItemAtPath:path
                       error:&error];
        if (!success) {
            ELOG(@"%@", error);
        }
    }
    */
        let docsDirectory = directoryForLogs
        do {
            let dirContents = try FileManager.default.contentsOfDirectory(atPath: docsDirectory)
            let logFiles = dirContents.filter { $0.hasSuffix(".pv") }
            for file in logFiles {
                if shouldDeleteFileWithName(file) {
                    do {
                        try FileManager.default.removeItem(atPath: docsDirectory + "/" + file)
                    } catch {
                        print("Error deleting old log file: \(error)")
                    }
                }
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }

    // MARK: - Internal
    public func shouldDeleteFileWithName(_ name: String) -> Bool {
        /*
          NSDateFormatter *format = [[NSDateFormatter alloc] init]; // DSwift - adding autorelease - this was leaking.
    [format setDateFormat:@"yyyy'-'MM'-'dd"];

    for(int i=0;i<7;i++){
        NSDate *day = [[NSDate date] dateByAddingTimeInterval:-60*60*24*i];
        NSString *dateString = [format stringFromDate:day];
        NSString *logname = [[NSString alloc] initWithFormat:@"pvlog_%@.txt",dateString];
        if([logname isEqualToString:name]){
            return NO;
        }
    }

    return YES;
    */
        return false
    }
}
