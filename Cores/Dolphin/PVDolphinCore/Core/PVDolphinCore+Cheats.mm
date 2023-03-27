#import <PVDolphin/PVDolphin.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

/* Dolphin Includes */
#include <algorithm>
#include <iterator>
#include <mutex>
#include <tuple>
#include <vector>

#include "Common/CommonPaths.h"
#include "Common/FileUtil.h"
#include "Core/Boot/Boot.h"
#include "Core/BootManager.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Config/MainSettings.h"
#include "Core/Config/SYSCONFSettings.h"
#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/GeckoCodeConfig.h"
#include "Core/ActionReplay.h"
#include "Core/ARDecrypt.h"
#include "Core/GeckoCode.h"
#include "Common/ChunkFile.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"

#include "Core/ConfigManager.h"
#include "Core/PowerPC/MMU.h"
#include "Core/PowerPC/PowerPC.h"

std::map<int, Gecko::GeckoCode> gcodes{};
std::map<int, ActionReplay::ARCode> arcodes{};
@implementation PVDolphinCore (Cheats)
#pragma mark - Cheats
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
    uint32_t cmd_addr, cmd_value;
    std::vector<std::string> arcode_encrypted_lines;
    Gecko::GeckoCode gcode;
    ActionReplay::ARCode arcode;
    gcode.codes.clear();
    arcode.ops.clear();
    NSString* nscode = [NSString stringWithUTF8String:[code UTF8String]];
    nscode = [nscode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    nscode = [nscode stringByReplacingOccurrencesOfString:@" " withString:@""];
    nscode = [nscode stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSArray *multipleCodes = [nscode componentsSeparatedByString:@"+"];
    for (int i=0; i < multipleCodes.count; i++)
    {
        NSString *singleCode = multipleCodes[i];
        if ([singleCode length] == 8 && multipleCodes.count > i+1) {
            singleCode = [singleCode stringByAppendingFormat:@"%@", multipleCodes[i+1]];
            i++;
        }
        if ([codeType isEqualToString:@"Gecko"])
        {
            Gecko::GeckoCode::Code gcodecode;
            NSString *address = [singleCode substringWithRange:NSMakeRange(0, 8)];
            NSString *value = [singleCode substringWithRange:NSMakeRange(8, singleCode.length - 8)];
            bool success_addr = TryParse(std::string("0x") + [address UTF8String], &cmd_addr);
            bool success_val = TryParse(std::string("0x") + [value UTF8String], &cmd_value);
            if (!success_addr || !success_val)
                return false;
            gcodecode.address = cmd_addr;
            gcodecode.data = cmd_value;
            gcodecode.original_line = [singleCode UTF8String];
            gcode.codes.push_back(gcodecode);
        }
        if ([codeType isEqualToString:@"Pro Action Replay"]) // Encrypted AR code
        {
            NSString *address = [singleCode substringWithRange:NSMakeRange(0, 8)];
            NSString *value = [singleCode substringWithRange:NSMakeRange(8, singleCode.length - 8)];
            NSCharacterSet* hex_set = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFabcdef0123456789"] invertedSet];
            if ([address rangeOfCharacterFromSet:hex_set].location == NSNotFound && [value rangeOfCharacterFromSet:hex_set].location == NSNotFound) {
                u32 addr = (u32)std::stoul([address UTF8String], nullptr, 16);
                u32 data = (u32)std::stoul([value UTF8String], nullptr, 16);
                arcode.ops.push_back(ActionReplay::AREntry(addr, data));
            } else {
                NSArray<NSString*>* blocks = [singleCode componentsSeparatedByString:@"-"];
                if ([blocks count] == 3 && [blocks[0] length] == 4 && [blocks[1] length] == 4 &&
                    [blocks[2] length] == 5)
                {
                    arcode_encrypted_lines.emplace_back(std::string([blocks[0] UTF8String]) + std::string([blocks[1] UTF8String]) + std::string([blocks[2] UTF8String]));
                } else
                    return false;
            }
        }
    }
    if ([codeType isEqualToString:@"Gecko"]) {
        gcode.name=[type UTF8String];
        gcode.user_defined=true;
        gcode.enabled=enabled;
        gcodes[cheatIndex]=gcode;
        NSLog(@"Applying Gecko Code size %d enabled %d\n", gcode.codes
               .size(), gcode.enabled);
        std::vector<Gecko::GeckoCode> activate;
        activate.clear();
        for (const auto& [key, value] : gcodes) {
            if (value.enabled)
                activate.push_back(value);
        }
        Gecko::SetActiveCodes(activate);
    }
    if ([codeType isEqualToString:@"Pro Action Replay"]) {
        if (arcode_encrypted_lines.size())
        {
            DecryptARCode(arcode_encrypted_lines,  &arcode.ops);
        }
        arcode.name=[type UTF8String];
        arcode.user_defined=true;
        arcode.enabled=enabled;
        arcodes[cheatIndex]=arcode;
        std::vector<ActionReplay::ARCode> activate;
        activate.clear();
        for (const auto& [key, value] : arcodes) {
            if (value.enabled)
                activate.push_back(value);
        }
        NSLog(@"Applying AR Code size %d enabled %d\n", arcode.ops
               .size(), arcode.enabled);
        // They are auto applied when activated
        ActionReplay::ApplyCodes(activate);
    }
    return true;
}
@end
