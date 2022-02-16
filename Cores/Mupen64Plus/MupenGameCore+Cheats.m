
//#import "MupenGameCore.h"
#import <PVMupen64Plus/PVMupen64Plus-Swift.h>

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/Core/src/main/version.h"
#import "Plugins/Core/src/plugin/plugin.h"

@implementation MupenGameCore (Cheats)

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
// Need to fix ambigious main.h inclusion
//    // Sanitize
//    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//
//    // Remove any spaces
//    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];
//
//    NSString *singleCode;
//    NSArray *multipleCodes = [code componentsSeparatedByString:@"+"];
//    m64p_cheat_code *gsCode = (m64p_cheat_code*) calloc([multipleCodes count], sizeof(m64p_cheat_code));
//    int codeCounter = 0;
//
//    for (singleCode in multipleCodes)
//    {
//        if ([singleCode length] == 12) // GameShark
//        {
//            // GameShark N64 format: XXXXXXXX YYYY
//            NSString *address = [singleCode substringWithRange:NSMakeRange(0, 8)];
//            NSString *value = [singleCode substringWithRange:NSMakeRange(8, 4)];
//
//            // Convert GS hex to int
//            unsigned int outAddress, outValue;
//            NSScanner* scanAddress = [NSScanner scannerWithString:address];
//            NSScanner* scanValue = [NSScanner scannerWithString:value];
//            [scanAddress scanHexInt:&outAddress];
//            [scanValue scanHexInt:&outValue];
//
//            gsCode[codeCounter].address = outAddress;
//            gsCode[codeCounter].value = outValue;
//            codeCounter++;
//        }
//    }
//
//    // Update address directly if code needs GS button pressed
//    if ((gsCode[0].address & 0xFF000000) == 0x88000000 || (gsCode[0].address & 0xFF000000) == 0xA8000000)
//    {
//        *(unsigned char *)((g_rdram + ((gsCode[0].address & 0xFFFFFF)^S8))) = (unsigned char)gsCode[0].value; // Update 8-bit address
//    }
//    else if ((gsCode[0].address & 0xFF000000) == 0x89000000 || (gsCode[0].address & 0xFF000000) == 0xA9000000)
//    {
//        *(unsigned short *)((g_rdram + ((gsCode[0].address & 0xFFFFFF)^S16))) = (unsigned short)gsCode[0].value; // Update 16-bit address
//    }
//    // Else add code as normal
//    else
//    {
//        enabled ? CoreAddCheat([code UTF8String], gsCode, codeCounter+1) : CoreCheatEnabled([code UTF8String], 0);
//    }
}

@end
