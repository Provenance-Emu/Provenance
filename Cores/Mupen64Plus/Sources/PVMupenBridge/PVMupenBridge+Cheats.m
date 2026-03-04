// We need function prototypes from the Mupen64Plus core API
#define M64P_CORE_PROTOTYPES 1

#import "PVMupenBridge+Cheats.h"

#import "api/m64p_frontend.h"
#import "api/m64p_types.h"

@import PVLogging;
@import PVLoggingObjC;

@implementation PVMupenBridge (Cheats)

// Maps sanitized code string -> user-provided label
static NSMutableDictionary *mupen_cheatList = nil;

- (NSArray<NSString *> *)cheatCodeTypes {
    return @[@"Game Shark"];
}

- (BOOL)supportsCheatCode {
    return YES;
}

- (BOOL)setCheatWithCode:(NSString *)code type:(NSString *)type codeType:(NSString *)codeType cheatIndex:(uint8_t)cheatIndex enabled:(BOOL)enabled {
    (void)codeType;   // Only GameShark is supported; codeType is not used
    (void)cheatIndex; // cheatIndex not used by the Mupen64Plus cheat API

    if (!mupen_cheatList) {
        mupen_cheatList = [[NSMutableDictionary alloc] init];
    }

    // Sanitize
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    code = [code uppercaseString];
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    if (!enabled) {
        // Only call CoreCheatEnabled if the cheat was actually registered
        if ([mupen_cheatList objectForKey:code]) {
            [mupen_cheatList removeObjectForKey:code];
            CoreCheatEnabled([code UTF8String], 0);
        }
        return YES;
    }

    // If this cheat is already registered, disable it first before re-adding
    if ([mupen_cheatList objectForKey:code]) {
        CoreCheatEnabled([code UTF8String], 0);
        [mupen_cheatList removeObjectForKey:code];
    }

    // Parse GameShark N64 codes separated by '+'
    // GameShark N64 format: XXXXXXXX YYYY (8 hex address + 4 hex value, space removed = 12 chars)
    NSArray<NSString *> *parts = [code componentsSeparatedByString:@"+"];

    // Normalize segments:
    // - Accept full 12-char segments as-is
    // - Combine adjacent 8-char and 4-char segments (e.g., "XXXXXXXX+YYYY") into one 12-char segment
    NSMutableArray<NSString *> *normalizedParts = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSUInteger i = 0; i < parts.count; i++) {
        NSString *part = parts[i];

        if (part.length == 12) {
            [normalizedParts addObject:part];
            continue;
        }

        if (part.length == 8 && i + 1 < parts.count) {
            NSString *nextPart = parts[i + 1];
            if (nextPart.length == 4) {
                NSString *combined = [part stringByAppendingString:nextPart];
                [normalizedParts addObject:combined];
                i++; // Skip the 4-char value segment we just consumed
                continue;
            }
        }

        DLOG(@"Mupen: Skipping unsupported cheat code segment before parsing (length %lu): %@", (unsigned long)part.length, part);
    }

    NSMutableArray<NSValue *> *codeValues = [NSMutableArray arrayWithCapacity:normalizedParts.count];

    for (NSString *part in normalizedParts) {
        if (part.length != 12) {
            DLOG(@"Mupen: Skipping unsupported normalized cheat code segment (length %lu): %@", (unsigned long)part.length, part);
            continue;
        }

        NSString *addressStr = [part substringWithRange:NSMakeRange(0, 8)];
        NSString *valueStr   = [part substringWithRange:NSMakeRange(8, 4)];

        unsigned int address = 0, value = 0;
        BOOL addressOK = [[NSScanner scannerWithString:addressStr] scanHexInt:&address];
        BOOL valueOK   = [[NSScanner scannerWithString:valueStr]   scanHexInt:&value];
        if (!addressOK || !valueOK) {
            DLOG(@"Mupen: Failed to parse hex in cheat segment: %@", part);
            continue;
        }

        m64p_cheat_code gsCode;
        gsCode.address = address;
        gsCode.value   = (int)value;
        [codeValues addObject:[NSValue valueWithBytes:&gsCode objCType:@encode(m64p_cheat_code)]];
    }

    if (codeValues.count == 0) {
        DLOG(@"Mupen: No valid GameShark segments found in code: %@", code);
        return NO;
    }

    m64p_cheat_code *codes = (m64p_cheat_code *)malloc(sizeof(m64p_cheat_code) * codeValues.count);
    if (!codes) {
        DLOG(@"Mupen: malloc failed allocating cheat code array");
        return NO;
    }
    for (NSUInteger i = 0; i < codeValues.count; i++) {
        [codeValues[i] getValue:&codes[i]];
    }

    m64p_error result = CoreAddCheat([code UTF8String], codes, (int)codeValues.count);
    free(codes);

    if (result == M64ERR_SUCCESS) {
        [mupen_cheatList setObject:(type ?: code) forKey:code];
        DLOG(@"Mupen: Added cheat '%@' (%lu segments)", code, (unsigned long)codeValues.count);
        return YES;
    }

    DLOG(@"Mupen: CoreAddCheat failed with error %d for code: %@", result, code);
    return NO;
}

- (void)resetCheatCodes {
    if (mupen_cheatList) {
        for (NSString *enabledCode in mupen_cheatList) {
            CoreCheatEnabled([enabledCode UTF8String], 0);
        }
        [mupen_cheatList removeAllObjects];
    }
}

@end
