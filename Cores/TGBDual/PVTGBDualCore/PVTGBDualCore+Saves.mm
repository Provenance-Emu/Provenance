//
//  PVTGBDualCore+Saves.h
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualCore+Audio.h"

@implementation PVTGBDualCore (Saves)

-(BOOL)supportsSaveStates {
    // TODO: Set to YES if saving works
    return NO;
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    /*
    size_t serial_size = retro_serialize_size();
    NSMutableData *stateData = [NSMutableData dataWithLength:serial_size];
    
    if(!retro_serialize([stateData mutableBytes], serial_size)) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                userInfo:@{
                                                           NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                           NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                           }];
            
            *error = newError;
        }
    }
    
    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:error];
    
    return success;
     */
    return NO;
}


- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error
{
    /*
    NSData *data = [NSData dataWithContentsOfFile:fileName options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:error];
    if(data == nil)  {
        if (error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Core failed to load save state. No Data at path.",
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];
            
            *error = newError;
        }
        
        return NO;
    }
    
    int serial_size = 678514;
    if(serial_size != [data length]) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeStateHasWrongSize
                                                userInfo:@{
                                                           NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                                                           NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the file %@ does not have the right size, %d expected, got: %ld.", fileName, serial_size, [data length]],
                                                           }];
            
            *error = newError;
        }
        return NO;
    }
    
    if(!retro_unserialize([data bytes], serial_size)) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
                                                                                                                                            NSLocalizedDescriptionKey : @"The save state data could not be read",
                                                                                                                                            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Could not read the file state in %@.", fileName]
                                                                                                                                            }];
            *error = newError;
        }
        return NO;
    }
    
    return YES;
     */
    return NO;
}


- (BOOL)loadSaveFile:(NSString *)path forType:(int)type {
    /*
    size_t size = retro_get_memory_size(type);
    void *ramData = retro_get_memory_data(type);
    
    if (size == 0 || !ramData)
    {
        return NO;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || ![data length])
    {
        NSLog(@"Couldn't load save file.");
    }
    
    [data getBytes:ramData length:size];
    return YES;
     */
    
    return NO;
}


- (BOOL)writeSaveFile:(NSString *)path forType:(int)type {
    /*
    size_t size = retro_get_memory_size(type);
    void *ramData = retro_get_memory_data(type);
    
    if (ramData && (size > 0))
    {
        retro_serialize(ramData, size);
        NSData *data = [NSData dataWithBytes:ramData length:size];
        BOOL success = [data writeToFile:path atomically:YES];
        if (!success)
        {
            NSLog(@"Error writing save file");
        }
        return success;
    } else {
        NSLog(@"TGBDual ramdata is invalid");
        return NO;
    }
     */
    return NO;
}

/*
static void loadSaveFile(const char* path, int type) {
    FILE *file;
    
    file = fopen(path, "rb");
    if ( !file )
    {
        return;
    }
    
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if (size == 0 || !data)
    {
        fclose(file);
        return;
    }
    
    int rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size )
    {
        NSLog(@"Couldn't load save file.");
    }
    
    NSLog(@"Loaded save file: %s", path);
    
    fclose(file);
}
*/


/*
static void writeSaveFile(const char* path, int type) {
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if ( data && size > 0 )
    {
        FILE *file = fopen(path, "wb");
        if ( file != NULL )
        {
            NSLog(@"Saving state %s. Size: %d bytes.", path, (int)size);
            retro_serialize(data, size);
            if ( fwrite(data, sizeof(uint8_t), size, file) != size )
                NSLog(@"Did not save state properly.");
            fclose(file);
        }
    }
}
*/

/*
- (NSData *)serializeStateWithError:(NSError *__autoreleasing *)outError {
    size_t length = retro_serialize_size();
    void *bytes = malloc(length);
    
    if(retro_serialize(bytes, length))
        return [NSData dataWithBytesNoCopy:bytes length:length];
    
    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:@{
                                                                                                                                NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                                                                                                NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                                                                                                }];
    }
    
    return nil;
}


- (BOOL)deserializeState:(NSData *)state withError:(NSError *__autoreleasing *)outError {
    size_t serial_size = retro_serialize_size();
    if(serial_size != [state length]) {
        if(outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeStateHasWrongSize userInfo:@{
                                                                                                                                    NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                                                                                                                                    NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
                                                                                                                                    }];
        }
        
        return NO;
    }
    
    if(retro_unserialize([state bytes], [state length]))
        return YES;
    
    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
                                                                                                                                NSLocalizedDescriptionKey : @"The save state data could not be read"
                                                                                                                                }];
    }
    
    return NO;
}
*/
@end
