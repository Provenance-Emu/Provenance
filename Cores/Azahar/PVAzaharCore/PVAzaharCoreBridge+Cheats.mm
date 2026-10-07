#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#include <memory>
#include <string>
#include "core/cheats/cheats.h"
#include "core/cheats/gateway_cheat.h"
#include "core/core.h"

static const NSTimeInterval PVAzaharCheatTimeout = 2.0;

@implementation PVAzaharCoreBridge (Cheats)

/// Replaces the engine entry named "PV<index>". Enabled -> a Gateway cheat from `code`; disabled -> removed.
- (BOOL)applyCheat:(NSString *)code index:(UInt8)cheatIndex enabled:(BOOL)enabled {
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
