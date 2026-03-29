#import <Foundation/Foundation.h>
#import "PVRetroArchCoreBridge+Archive.h"
@import PVArchiving;

@interface PVRetroArchCoreBridge (Archive)
@end

@implementation PVRetroArchCoreBridge (Archive)
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
    return [[PVArchiveHelper shared] extractLZH:atPath toDestination:toDestination overwrite:overwrite];
}

-(BOOL)extractZIP:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    return [[PVArchiveHelper shared] extractZIP:atPath toDestination:toDestination overwrite:overwrite];
}

-(BOOL)isArchive:(NSString *)atPath {
    return [[PVArchiveHelper shared] isArchive:atPath];
}

-(BOOL)extractArchive:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite {
    return [[PVArchiveHelper shared] extractArchive:atPath toDestination:toDestination overwrite:overwrite];
}
@end
