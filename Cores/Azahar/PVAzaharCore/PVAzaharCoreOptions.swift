import Foundation
import PVCoreBridge
import PVLogging
import PVSupport
import UIKit

/// Option definitions for the Azahar 3DS core. Enumeration values are the raw numbers the bridge expects
/// (`Settings::TextureFilter` 0...5, layout UI indices 0...4, region -1 = auto).
@objc public final class PVAzaharCoreOptions: NSObject, CoreOptions {
    // MARK: Graphics
    static var resolutionOption: CoreOption {
        .enumeration(.init(title: "Resolution Upscaling", description: "Internal render scale. Higher costs GPU time.", requiresRestart: true),
                     values: (1...6).map { .init(title: "\($0)X", description: nil, value: $0) }, defaultValue: 1)
    }
    /// tvOS has no touch screen to stack under the top one, so it defaults to Large Screen.
    #if os(tvOS)
    static let defaultLayout = 2
    #else
    static let defaultLayout = 0
    #endif
    // The bridge reads layout, swap, CPU clock and speed limit only at boot, hence requiresRestart.
    static var layoutOption: CoreOption {
        .enumeration(.init(title: "Screen Layout", description: nil, requiresRestart: true),
                     values: [
                        .init(title: "Default (stacked)", description: nil, value: 0),
                        .init(title: "Single Screen", description: nil, value: 1),
                        .init(title: "Large Screen", description: nil, value: 2),
                        .init(title: "Side by Side", description: nil, value: 3),
                        .init(title: "Hybrid", description: nil, value: 4)
                     ], defaultValue: defaultLayout)
    }
    static var swapScreensOption: CoreOption {
        .bool(.init(title: "Swap Screens", description: nil, requiresRestart: true), defaultValue: false)
    }
    static var hardwareShaderOption: CoreOption {
        .bool(.init(title: "Hardware Shader", description: "GPU vertex/geometry shaders. Disable only for debugging.", requiresRestart: true), defaultValue: true)
    }
    static var accurateMulOption: CoreOption {
        .bool(.init(title: "Accurate Multiplication", description: "Fixes lighting glitches in some games at a small cost.", requiresRestart: true), defaultValue: true)
    }
    static var asyncShaderOption: CoreOption {
        .bool(.init(title: "Async Shader Compilation", description: "Avoids stutter while shaders compile; may show brief missing geometry.", requiresRestart: true), defaultValue: true)
    }
    static var asyncPresentOption: CoreOption {
        .bool(.init(title: "Async Presentation", description: nil, requiresRestart: true), defaultValue: true)
    }
    static var diskShaderCacheOption: CoreOption {
        .bool(.init(title: "Disk Shader Cache", description: nil, requiresRestart: true), defaultValue: true)
    }
    static var textureFilterOption: CoreOption {
        .enumeration(.init(title: "Texture Filter", description: nil, requiresRestart: true),
                     values: [
                        .init(title: "None", description: nil, value: 0),
                        .init(title: "Anime4K", description: nil, value: 1),
                        .init(title: "Bicubic", description: nil, value: 2),
                        .init(title: "ScaleForce", description: nil, value: 3),
                        .init(title: "xBRZ", description: nil, value: 4),
                        .init(title: "MMPX", description: nil, value: 5)
                     ], defaultValue: 0)
    }

    // MARK: System
    static var new3DSOption: CoreOption {
        .bool(.init(title: "New 3DS Mode", description: "Extra CPU cores and memory. Only needed by a few New 3DS-only games; can change behaviour in others.", requiresRestart: true), defaultValue: false)
    }
    static var cpuClockOption: CoreOption {
        .enumeration(.init(title: "CPU Clock", description: "Below 100% speeds up some games; above 100% can reduce lag or break games.", requiresRestart: true),
                     values: [25, 50, 75, 100, 125, 150, 200, 300, 400].map { .init(title: "\($0)%", description: nil, value: $0) }, defaultValue: 100)
    }
    static var regionOption: CoreOption {
        .enumeration(.init(title: "Region", description: nil, requiresRestart: true),
                     values: [
                        .init(title: "Auto", description: nil, value: -1), .init(title: "Japan", description: nil, value: 0),
                        .init(title: "USA", description: nil, value: 1), .init(title: "Europe", description: nil, value: 2),
                        .init(title: "Australia", description: nil, value: 3), .init(title: "China", description: nil, value: 4),
                        .init(title: "Korea", description: nil, value: 5), .init(title: "Taiwan", description: nil, value: 6)
                     ], defaultValue: -1)
    }
    /// azahar treats `frame_limit == 0` as unlimited.
    static let unlimitedSpeedPercent = 0
    static var frameLimitOption: CoreOption {
        .enumeration(.init(title: "Speed Limit", description: nil, requiresRestart: true),
                     values: [50, 100, 150, 200, unlimitedSpeedPercent].map {
                         .init(title: $0 == unlimitedSpeedPercent ? "Unlimited" : "\($0)%", description: nil, value: $0)
                     }, defaultValue: 100)
    }

    // MARK: Audio
    static var audioStretchOption: CoreOption {
        .bool(.init(title: "Audio Stretching", description: "Keeps audio smooth when the game runs slow.", requiresRestart: true), defaultValue: true)
    }
    static var realtimeAudioOption: CoreOption {
        .bool(.init(title: "Realtime Audio", description: "Lower latency; may crackle on slow devices.", requiresRestart: true), defaultValue: true)
    }

    // MARK: Data
    /// Behaves like a button: switching it on prompts for confirmation, runs the import, then switches itself off.
    static var importFromEmuThreeOption: CoreOption {
        .bool(.init(title: "Import 3DS data from emuThreeDS",
                    description: "Moves NAND, SD card, system files, config and cheats into Azahar. emuThreeDS will no longer see them. Save states are not moved.",
                    requiresRestart: false),
              defaultValue: false,
              valueHandler: { value in
                  guard (value as? Bool) == true else { return }
                  Task { @MainActor in presentImportPrompt() }
                  // Reset the global key and, in per-game scope, the key the UI just wrote for this game.
                  setValue(false, forOption: importFromEmuThreeOption)
                  if let md5 = currentGameMD5 { setValue(false, forOption: importFromEmuThreeOption, andMD5: md5) }
              })
    }

    @MainActor private static func presentImportFailure(_ error: Swift.Error) {
        let alert = UIAlertController(title: "Import failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topViewController()?.present(alert, animated: true)
    }

    @MainActor private static func presentImportPrompt() {
        let migrator = PVAzaharDataMigrator(legacyRoot: PVAzaharDataMigrator.defaultLegacyRoot(),
                                            targetRoot: PVAzaharDataMigrator.defaultTargetRoot())
        let plan = migrator.plan()
        let megabytes = Double(plan.totalBytes) / bytesPerMegabyte
        let kept = plan.conflicts.isEmpty ? "" : " \(plan.conflicts.count) file(s) Azahar already has will be left in place."
        let message = plan.hasWork
            ? String(format: "Move %.1f MB of emuThreeDS data into Azahar? emuThreeDS will stop seeing it.", megabytes) + kept
            : "Nothing to import: no emuThreeDS data found, or it was already imported."
        let alert = UIAlertController(title: "Import 3DS data", message: message, preferredStyle: .alert)
        if plan.hasWork {
            alert.addAction(UIAlertAction(title: "Move", style: .destructive) { _ in
                DispatchQueue.global(qos: .utility).async {
                    let failure: Swift.Error?
                    do {
                        try migrator.apply()
                        ILOG("[PVAzahar] imported emuThreeDS data")
                        failure = nil
                    } catch {
                        ELOG("[PVAzahar] import failed: \(error)")
                        failure = error
                    }
                    guard let failure else { return }
                    DispatchQueue.main.async { presentImportFailure(failure) }
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        topViewController()?.present(alert, animated: true)
    }

    @MainActor private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

    private static let bytesPerMegabyte = 1_048_576.0

    public static var options: [CoreOption] {
        [.group(.init(title: "Graphics", description: nil), subOptions: [
            resolutionOption, layoutOption, swapScreensOption, textureFilterOption, hardwareShaderOption,
            accurateMulOption, asyncShaderOption, asyncPresentOption, diskShaderCacheOption]),
         .group(.init(title: "System", description: nil), subOptions: [new3DSOption, cpuClockOption, regionOption, frameLimitOption]),
         .group(.init(title: "Audio", description: nil), subOptions: [audioStretchOption, realtimeAudioOption]),
         .group(.init(title: "Data", description: nil), subOptions: [importFromEmuThreeOption])]
    }

    /// Copies the stored option values into the bridge. Call before `loadFile`.
    @objc public static func apply(to bridge: PVAzaharCoreBridge) {
        func int(_ option: CoreOption) -> Int { PVAzaharCore.valueForOption(option) }
        func bool(_ option: CoreOption) -> Bool { PVAzaharCore.valueForOption(option) }
        bridge.resolutionFactor = int(resolutionOption)
        bridge.layoutOption = int(layoutOption)
        bridge.swapScreens = bool(swapScreensOption)
        bridge.hardwareShader = bool(hardwareShaderOption)
        bridge.accurateMultiplication = bool(accurateMulOption)
        bridge.asyncShaderCompilation = bool(asyncShaderOption)
        bridge.asyncPresentation = bool(asyncPresentOption)
        bridge.diskShaderCache = bool(diskShaderCacheOption)
        bridge.textureFilter = int(textureFilterOption)
        bridge.new3DSMode = bool(new3DSOption)
        bridge.cpuClockPercent = int(cpuClockOption)
        bridge.regionValue = int(regionOption)
        bridge.frameLimitPercent = int(frameLimitOption)
        bridge.audioStretching = bool(audioStretchOption)
        bridge.realtimeAudio = bool(realtimeAudioOption)
    }
}
