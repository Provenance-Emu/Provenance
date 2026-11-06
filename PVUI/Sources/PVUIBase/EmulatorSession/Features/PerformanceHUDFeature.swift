//
//  PerformanceHUDFeature.swift
//  PVUI
//
//  The in-game FPS / CPU / memory HUD, pinned to the top-right of the GPU view.
//  Shown while `Defaults[.showFPSCount]` is on; never shown for skip-layout
//  cores, which draw into their own view. Replaces the former
//  `PVEmulatorViewController+PerformanceLabls` extension.
//

import Combine
import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVSettings
import PVThemes
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PerformanceHUDFeature: EmulatorSessionFeature {
    public static let id: EmulatorFeatureID = "performanceHUD"

    /// The HUD's refresh period, in seconds.
    static let refreshInterval: TimeInterval = 0.25
    /// Width of the HUD box; the label needs the wider box at tvOS point sizes.
    nonisolated static var hudWidth: CGFloat {
        #if os(tvOS)
        return 340
        #else
        return 210
        #endif
    }
    /// Monospaced point size of the label; tvOS is read from across a room.
    nonisolated static var labelFontSize: CGFloat {
        #if os(tvOS)
        return 22
        #else
        return 12
        #endif
    }
    private static let hudInset: CGFloat = 10
    private static let labelVerticalInset: CGFloat = 6
    private static let labelHorizontalInset: CGFloat = 8

    private weak var host: (any EmulatorSessionHost)?
    private var timer: Timer?
    private var themeObserver: NSObjectProtocol?
    private var preferenceCancellable: AnyCancellable?

    private lazy var hudView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 8
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        label.textAlignment = .right // RTL: do not flip — the counter is always pinned to the right edge (not trailing) regardless of locale
        label.lineBreakMode = .byClipping
        label.isOpaque = false
        label.numberOfLines = 5
        label.adjustsFontSizeToFitWidth = false
        label.font = .monospacedSystemFont(ofSize: Self.labelFontSize, weight: .regular)
        return label
    }()

    public init?(host: any EmulatorSessionHost) {
        self.host = host
    }

    // MARK: - EmulatorSessionFeature

    public func attach() {
        guard preferenceCancellable == nil else { return }
        preferenceCancellable = Defaults.publisher(.showFPSCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.applyVisibilityPreference(change.newValue)
            }
        applyVisibilityPreference(Defaults[.showFPSCount])
    }

    public func detach() {
        preferenceCancellable?.cancel()
        preferenceCancellable = nil
        hide()
    }

    public func handlePauseMenuTile(id: String) -> Bool {
        guard id == "fpsCounterToggle" else { return false }
        Defaults[.showFPSCount].toggle()
        return true
    }

    // MARK: - Host-facing

    /// Hides the HUD from a capture (screenshots, autosave thumbnails) without
    /// tearing it down.
    public var isHidden: Bool {
        get { hudView.isHidden }
        set {
            hudView.isHidden = newValue
            label.isHidden = newValue
        }
    }

    // MARK: - Decision tables

    /// Whether the HUD is on screen: the preference is on and the core presents through the host's GPU view.
    nonisolated static func isShown(enabled: Bool, skipLayout: Bool) -> Bool {
        enabled && !skipLayout
    }

    /// The numbers one refresh of the HUD shows.
    struct Metrics: Equatable {
        /// Emulation speed relative to the core's target frame rate, in percent.
        let coreSpeed: Double
        /// Time between the GPU view's last two draws, in milliseconds (0 when unknown).
        let drawTimeMilliseconds: Double
        /// The frame rate the user sees: emulation FPS, falling back to the render rate.
        let displayFPS: Double
    }

    /// Reduces the raw core and GPU-view readings to what the label shows.
    ///
    /// - Parameters:
    ///   - emulationFPS: `core.emulationFPS`, the frames the core produced per second.
    ///   - frameInterval: `core.frameInterval`, treated as a target FPS (e.g. 60) across the codebase, not seconds per frame.
    ///   - drawTimeMilliseconds: the GPU view's `timeSinceLastDraw`, in milliseconds.
    ///   - gpuFPS: the Metal view's own frame counter, used to derive a draw time when the view reports none.
    ///   - renderFPS: `core.renderFPS`, the last fallback for the render rate.
    nonisolated static func metrics(emulationFPS: Double,
                                    frameInterval: Double,
                                    drawTimeMilliseconds: Double,
                                    gpuFPS: Double,
                                    renderFPS: Double) -> Metrics {
        let targetFPS = frameInterval > 0 ? frameInterval : 60.0
        let coreSpeed = (targetFPS > 0 && emulationFPS >= 0) ? (emulationFPS / targetFPS) * 100 : 0

        var drawTime = drawTimeMilliseconds
        if drawTime <= 0, gpuFPS > 0 {
            drawTime = 1000.0 / gpuFPS
        }
        let resolvedRenderFPS: Double
        if drawTime > 0 {
            resolvedRenderFPS = 1000.0 / drawTime
        } else {
            resolvedRenderFPS = renderFPS > 0 ? renderFPS : emulationFPS
        }
        let displayFPS = emulationFPS > 0 ? emulationFPS : resolvedRenderFPS
        return Metrics(coreSpeed: coreSpeed, drawTimeMilliseconds: drawTime, displayFPS: displayFPS)
    }

    /// The five-line label: core speed, draw time, FPS, CPU percent and memory in MB.
    nonisolated static func labelText(_ metrics: Metrics, cpuPercent: Double, memoryUsed: UInt64, memoryTotal: UInt64) -> String {
        let cpuFormatted = String(format: "%5.1f", cpuPercent)
        let memUsedMB = Int(memoryUsed / 1024 / 1024)
        let memTotalMB = Int(memoryTotal / 1024 / 1024)
        return String(
            format: "Core speed %6.2f%%\nDraw time %6.2fms\nFPS %6.2f\nCPU %@%%\nMem %5d/%5d(MB)",
            metrics.coreSpeed, metrics.drawTimeMilliseconds, metrics.displayFPS, cpuFormatted, memUsedMB, memTotalMB
        )
    }

    // MARK: - Private

    private func applyVisibilityPreference(_ enabled: Bool) {
        guard let host else { return }
        if Self.isShown(enabled: enabled, skipLayout: host.core.skipLayout) {
            show(in: host.gpuViewController.view)
            hudView.alpha = 1.0
        } else {
            hide()
        }
    }

    private func show(in container: UIView) {
        /// Avoid duplicate view/constraint installation if called more than once.
        guard hudView.superview == nil else {
            applyTheme()
            return
        }
        container.addSubview(hudView)
        hudView.addSubview(label)

        NSLayoutConstraint.activate([
            hudView.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.hudInset),
            hudView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Self.hudInset),
            hudView.widthAnchor.constraint(equalToConstant: Self.hudWidth),

            label.topAnchor.constraint(equalTo: hudView.topAnchor, constant: Self.labelVerticalInset),
            label.bottomAnchor.constraint(equalTo: hudView.bottomAnchor, constant: -Self.labelVerticalInset),
            label.leadingAnchor.constraint(equalTo: hudView.leadingAnchor, constant: Self.labelHorizontalInset),
            label.trailingAnchor.constraint(equalTo: hudView.trailingAnchor, constant: -Self.labelHorizontalInset)
        ])

        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(forName: .themeDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyTheme()
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func hide() {
        timer?.invalidate()
        timer = nil
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
            self.themeObserver = nil
        }
        hudView.removeFromSuperview()
    }

    private func applyTheme() {
        let palette = ThemeManager.shared.currentPalette
        let bg = palette.settingsCellBackground ?? palette.gameLibraryBackground
        let fg = palette.settingsCellText ?? palette.gameLibraryText

        hudView.backgroundColor = bg.withAlphaComponent(palette.dark ? 0.55 : 0.70)
        hudView.layer.borderWidth = 1.0 / UIScreen.main.scale
        hudView.layer.borderColor = palette.defaultTintColor.withAlphaComponent(palette.dark ? 0.25 : 0.15).cgColor

        label.textColor = fg
        label.shadowColor = UIColor.black.withAlphaComponent(palette.dark ? 0.45 : 0.25)
        label.shadowOffset = .init(width: 0, height: 1)
    }

    private func refresh() {
        guard let host, !host.isQuitting else { return }
        let core = host.core
        let gpu = host.gpuViewController
        /// `core.emulationFPS` is the primary metric (most accurate for emulation, especially 3D cores);
        /// the GPU view's draw timing gives the render rate, with `core.renderFPS` as the last fallback.
        let metrics = Self.metrics(emulationFPS: core.emulationFPS,
                                   frameInterval: core.frameInterval,
                                   drawTimeMilliseconds: gpu.timeSinceLastDraw * 1000,
                                   gpuFPS: Double((gpu as? PVMetalViewController)?.framesPerSecond ?? 0),
                                   renderFPS: core.renderFPS)
        let memory = Self.memoryUsage()
        label.text = Self.labelText(metrics, cpuPercent: Self.cpuUsage(), memoryUsed: memory.used, memoryTotal: memory.total)
    }

    // MARK: - Process metrics

    nonisolated static func memoryUsage() -> (used: UInt64, total: UInt64) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }

        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }

    nonisolated static func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }
}
