#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Archive.h"

NSString* PC98_EXTENSIONS  = @"d88|88d|d98|98d|fdi|xdf|hdm|dup|2hd|tfd|nfd|hd4|hd5|hd9|fdd|h01|hdb|ddb|dd6|dcp|dcu|flp|img|ima|bin|fim|thd|nhd|hdi|vhd|slh|hdn|cmd";

@interface PVRetroArchCore (Archive)
@end

@implementation PVRetroArchCore (Archive)
- (NSMutableArray *)getPC98Files:(NSString *)path {
    NSError *error = nil;
    NSMutableArray<NSDictionary *> *files = [NSMutableArray arrayWithArray:@[]];
    NSDirectoryEnumerator *contents = [[NSFileManager defaultManager]
        enumeratorAtPath:path];
    for (NSString *obj in contents) {
        // Rename to Lowercase
        NSString *file=[path stringByAppendingString:[NSString stringWithFormat:@"/%@",obj]];
        NSString *fileLC=[path stringByAppendingString:[NSString stringWithFormat:@"/%@",obj.lowercaseString]];
        NSData *decode = [fileLC dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        fileLC = [[NSString alloc] initWithData:decode encoding:NSUTF8StringEncoding];
        if (![file isEqualToString:fileLC]) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:fileLC]) {
                [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
            } else {
                [[NSFileManager defaultManager] moveItemAtPath:file toPath:fileLC error:nil];
            }
        }
        file=fileLC;
        NSLog(@"Archive: File %@\n", file);
        NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
        BOOL isDirectory = attribs.fileType == NSFileTypeDirectory;
        if (!isDirectory) {
            if ([self extractArchive:file toDestination:path overwrite:false]) {
                // Extract Archive
                [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
            } else if ([PC98_EXTENSIONS localizedCaseInsensitiveContainsString:file.pathExtension]) {
                // Return PC98 ROMs
                NSDate* modDate = [attribs objectForKey:NSFileCreationDate];
                [files addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  file, @"path",
                                  modDate, @"lastModDate",
                                  nil]];
            }
        }
    }
    return files;
}
- (NSString *)checkROM_PC98:(NSString*)romFile {
    NSString *unzipPath = [self getExtractedRomDirectory];
    NSError *error;
    NSLog(@"Archive: Extract Path: %@", unzipPath);
    if (!unzipPath) {
        return romFile;
    }
    NSString *password = @"";
    BOOL success = [self extractArchive:romPath toDestination:unzipPath overwrite:false];
    if (!success) {
        NSLog(@"Archive: Could not be Extracted");
        return romFile;
    }

    // Get Extracted Files
    NSMutableArray<NSDictionary *> *files = [self getPC98Files:unzipPath];

    // Refresh with Extracted archive in the the archive
    files = [self getPC98Files:unzipPath];

    // Sort Extracted ROMs
    NSArray* sortedFiles = [files sortedArrayUsingComparator: ^(id path1, id path2) {
        NSComparisonResult comp = [[path2 objectForKey:@"path"] compare:
                                   [path1 objectForKey:@"path"]];
        if (comp == NSOrderedDescending) {
            comp = NSOrderedAscending;
        } else if(comp == NSOrderedAscending){
            comp = NSOrderedDescending;
        }
        return comp;
    }];

    // Create run.cmd
    NSString* content = @"./np2";
    // Find / Append system disk first
    for (NSDictionary *obj in sortedFiles) {
        NSString *file=[obj objectForKey:@"path"];
        if ([file containsString:@"_s"]) {
            file = [file stringByReplacingOccurrencesOfString:unzipPath
                                                   withString:@"."];
            content = [content stringByAppendingString:
             [NSString stringWithFormat:@" \"%@\"", file]];
        }
    }
    bool isHDI=false;
    for (NSDictionary *obj in sortedFiles) {
        NSString *file=[obj objectForKey:@"path"];
        file = [file stringByReplacingOccurrencesOfString:unzipPath
                                               withString:@"."];
        NSLog(@"Archive: %@ Extension %@\n", file, file.pathExtension);
        if ([file.pathExtension containsString:@"hd"]) {
            isHDI=true;
        } else if (isHDI) {
            continue;
        }
        content = [content stringByAppendingString:
         [NSString stringWithFormat:@" \"%@\"", file]];
    }
    NSString *fileName = [NSString stringWithFormat:@"%@/run.cmd", [self getExtractedRomDirectory]];
    NSLog(@"Archive: Writing %@ to %@", content, fileName);
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
        [content writeToFile:fileName
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:&error];
    }
    if (error) {
        NSLog(@"Archive: run.cmd write error %@",error);
        if (sortedFiles.count)
            return [sortedFiles[0] objectForKey:@"path"];
        else
            return romFile;
    }
    if (sortedFiles.count)
        return fileName;
    else
        return romFile;
}
@end
