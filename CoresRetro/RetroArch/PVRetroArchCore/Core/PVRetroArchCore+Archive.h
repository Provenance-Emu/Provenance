#import <PVRetroArch/PVRetroArchCore.h>

NS_ASSUME_NONNULL_BEGIN
@interface PVRetroArchCore (Archive)
- (NSString *)checkROM_MAME:(NSString*)romFile;
- (NSString *)checkROM_AppleII:(NSString*)romFile;
- (NSString *)checkROM_PC98:(NSString*)romFile;
- (NSString *)checkROM:(NSString*)romFile;
- (NSString *)getExtractedRomDirectory;

- (BOOL)extractLZH:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite;
- (BOOL)extractZIP:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite;
- (BOOL)extractRAR:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite;

- (BOOL)extractArchive:(NSString *)atPath toDestination:(NSString *)toDestination overwrite:(BOOL)overwrite;
- (BOOL)isArchive:(NSString *)atPath;
@end
NS_ASSUME_NONNULL_END
