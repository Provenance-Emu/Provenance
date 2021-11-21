

#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

@class OERingBuffer;

__attribute__((visibility("default")))
@interface PVDuckStationCore : PVEmulatorCore <PV5200SystemResponderClient>
@end

// for Swift
@interface PVDuckStationCore()
@property (nonatomic, assign) NSUInteger maxDiscs;
-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
-(void)changeDisplayMode;

# pragma CheatCodeSupport
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled error:(NSError**)error;
- (BOOL)getCheatSupport;
@end
