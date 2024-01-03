#import <PVEmuThree/PVEmuThree.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#import "../emuThree/CitraWrapper.h"

@implementation PVEmuThreeCore (Cheats)
#pragma mark - Cheats
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
    if (!enabled)
        return true;
    NSLog(@"Received Cheat %s", [code UTF8String]);
    NSArray *codes = [code componentsSeparatedByString:@"+"];
    NSString *cheatCode = @"";
    int index=1;
    bool skip=false;
    for (id hex in codes) {
        if ([hex containsString:@"["])
            skip=true;
        if (!skip) {
            if (index % 2 == 0)
                cheatCode = [NSString stringWithFormat:@"%@ %@\n", cheatCode, hex];
            else
                cheatCode = [NSString stringWithFormat:@"%@%@", cheatCode, hex];
            index+=1;
        }
        if ([hex containsString:@"]"])
            skip=false;

    }
    NSLog(@"Parsed Cheat %s", [cheatCode UTF8String]);
    [CitraWrapper.sharedInstance addCheat:cheatCode];
    return true;
}
@end
