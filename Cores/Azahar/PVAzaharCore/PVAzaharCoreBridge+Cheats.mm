#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#include <memory>
#include <string>
#include "core/cheats/cheats.h"
#include "core/cheats/gateway_cheat.h"
#include "core/core.h"

static const NSTimeInterval PVAzaharCheatTimeout = 2.0;

// setCheat: is declared in the primary @interface (CLAUDE.md: categories can be elided) and defined here.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation PVAzaharCoreBridge (Cheats)

/// Replaces the engine entry named "PV<index>". Enabled -> a Gateway cheat from `code`; disabled -> removed.
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error {
    const std::string codeText([code UTF8String] ?: "");
    const std::string name = "PV" + std::to_string(cheatIndex);
    return [self runOnEmuThreadAndWait:[=] {
        auto& engine = Core::System::GetInstance().CheatEngine();
        const auto cheats = engine.GetCheats();
        for (std::size_t i = 0; i < cheats.size(); ++i) {
            if (cheats[i]->GetName() == name) { engine.RemoveCheat(i); break; }
        }
        if (enabled) {
            auto cheat = std::make_shared<Cheats::GatewayCheat>(name, codeText, "");
            cheat->SetEnabled(true);
            engine.AddCheat(std::move(cheat));
        }
    } timeout:PVAzaharCheatTimeout];
}

@end
#pragma clang diagnostic pop
