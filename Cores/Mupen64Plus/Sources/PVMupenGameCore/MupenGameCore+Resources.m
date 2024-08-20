#import "MupenGameCore+Controls.h"
#import <PVMupen64Plus/PVMupen64Plus-Swift.h>

@implementation MupenGameCore

- (void)copyIniFiles:(NSString*)romFolder {
    NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
    
    // Copy default config files if they don't exist
    NSArray<NSString*>* iniFiles = @[@"GLideN64.ini", @"GLideN64.custom.ini", @"RiceVideoLinux.ini", @"mupen64plus.ini"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Create destination folder if missing
    
    BOOL isDirectory;
    if (![fm fileExistsAtPath:romFolder isDirectory:&isDirectory]) {
        ILOG(@"ROM data folder doesn't exist, creating %@", romFolder);
        NSError *error;
        BOOL success = [fm createDirectoryAtPath:romFolder withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            ELOG(@"Failed to create destination folder %@. Error: %@", romFolder, error.localizedDescription);
            return;
        }
    }
    
    for (NSString *iniFile in iniFiles) {
        NSString *destinationPath = [romFolder stringByAppendingPathComponent:iniFile];

        BOOL fileExists = [fm fileExistsAtPath:destinationPath];
        if (!fileExists) {
            NSString *fileName = [iniFile stringByDeletingPathExtension];
            NSString *extension = [iniFile pathExtension];
            NSString *source = [coreBundle pathForResource:fileName
                                                    ofType:extension];
            if (source == nil) {
                ELOG(@"No resource path found for file %@", iniFile);
                continue;
            }
            NSError *copyError = nil;
            BOOL didCopy = [fm copyItemAtPath:source
                                       toPath:destinationPath
                                        error:&copyError];
            if (!didCopy) {
                ELOG(@"Failed to copy app bundle file %@\n%@", iniFile, copyError.localizedDescription);
            } else {
                ILOG(@"Copied %@ from app bundle to %@", iniFile, destinationPath);
            }
        } else {
            ILOG(@"File already exists at path, no need to copy. <%@>", destinationPath);
        }
    }
}

-(void)createHiResFolder:(NSString*)romFolder {
    // Create the directory if this option is enabled to make it easier for users to upload packs
    BOOL hiResTextures = YES;
    if (hiResTextures) {
        // Create the directory for hires_texture, this is a constant in mupen source
        NSArray<NSString*>* subPaths = @[@"/hires_texture/", @"/cache/", @"/texture_dump/"];
        for(NSString *subPath in subPaths) {
            NSString *highResPath = [romFolder stringByAppendingPathComponent:subPath];
            NSError *error;
            BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:highResPath
                                                     withIntermediateDirectories:YES
                                                                      attributes:nil
                                                                           error:&error];
            if (!success) {
                ELOG(@"Error creating hi res texture path: %@", error.localizedDescription);
            }
        }
    }
}


@end
