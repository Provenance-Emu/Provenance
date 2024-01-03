#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Archive.h"

#import "ZipArchive.h"
#import "LzhArchive.h"
#import "URKArchive.h"

@interface PVRetroArchCore (Archive)
@end

@implementation PVRetroArchCore (Archive)
- (NSString *)checkROM:(NSString*)romFile {
    NSLog(@"Core %@ System %@ Rom %@\n", [self coreIdentifier], [self systemIdentifier], romFile);
    if([[self systemIdentifier] containsString:@"com.provenance.pc98"]) {
        NSString *file=[self checkROM_PC98:romFile];
        NSLog(@"Core Rom %@\n", file);
        return file;
    }
    if([[self systemIdentifier] containsString:@"com.provenance.appleII"]) {
        NSString *file=[self checkROM_AppleII:romFile];
        NSLog(@"Core Rom %@\n", file);
        return file;
    }
    if([[self systemIdentifier] containsString:@"mame"] || 
       [[self systemIdentifier] containsString:@"neogeo"]
       ) {
        NSString *file=[self checkROM_MAME:romFile];
        NSLog(@"Core Rom %@\n", file);
        return file;
    }
    return romFile;
}

- (NSString *)getExtractedRomDirectory {
    NSData *decode = [self.batterySavesPath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *path = [[NSString alloc] initWithData:decode encoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return path;
}

-(BOOL)extractLZH:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    return [LzhArchive unLzhFileAtPath:atPath
                         toDestination:toDestination
                             overwrite:overwrite];
}

-(BOOL)extractZIP:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    return [SSZipArchive unzipFileAtPath:atPath
                           toDestination:toDestination
                      preserveAttributes:NO
                               overwrite:overwrite
                          nestedZipLevel:3
                                password:nil
                                   error:nil
                                delegate:nil
                         progressHandler:nil
                       completionHandler:nil];
}

-(BOOL)extractRAR:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    NSError *error = nil;
    URKArchive *archive = [[URKArchive alloc] initWithPath:atPath error:&error];
    NSArray<NSString*> *filesInArchive = [archive listFilenames:&error];
    for (NSString *name in filesInArchive) {
        NSLog(@"Archived file: %@\n", name);
    }
    return [archive extractFilesTo:toDestination overwrite:overwrite error:nil];
}
-(BOOL)isArchive:(NSString *)atPath {
    return ([atPath localizedCaseInsensitiveContainsString:@".zip"] ||
            [atPath localizedCaseInsensitiveContainsString:@".lzh"] ||
            [atPath localizedCaseInsensitiveContainsString:@".rar"]);
}

-(BOOL)extractArchive:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    if ([atPath localizedCaseInsensitiveContainsString:@".zip"]) {
        return [self extractZIP:atPath toDestination:toDestination overwrite:overwrite];
    }
    if ([atPath localizedCaseInsensitiveContainsString:@".lzh"]) {
        return [self extractLZH:atPath toDestination:toDestination overwrite:overwrite];
    }
    if ([atPath localizedCaseInsensitiveContainsString:@".rar"]) {
        return [self extractRAR:atPath toDestination:toDestination overwrite:overwrite];
    }
    return false;
}
@end
