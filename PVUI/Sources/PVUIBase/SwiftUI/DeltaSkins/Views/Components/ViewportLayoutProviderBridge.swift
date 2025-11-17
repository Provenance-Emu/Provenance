//
//  ViewportLayoutProviderBridge.swift
//
//  Bridge between SwiftUI views and PVViewportLayoutProvider protocol
//  Allows SwiftUI views to provide viewport layout information via protocol
//

import UIKit
import SwiftUI
import PVEmulatorCore

/// Bridge class that implements PVViewportLayoutProvider for SwiftUI views
/// This allows SwiftUI views to communicate viewport frames via protocol instead of notifications
@objc
public class ViewportLayoutProviderBridge: NSObject, PVViewportLayoutProvider {

    /// Closure to calculate viewport frame
    private let calculateFrame: (CGSize, UIEdgeInsets, Bool) -> CGRect?

    /// Closure to request recalculation
    private let requestRecalculation: () -> Void

    /// Weak reference to the core to notify delegate
    private weak var core: PVEmulatorCore?

    /// Initialize the bridge with calculation and recalculation closures
    /// - Parameters:
    ///   - core: The emulator core to notify when frames update
    ///   - calculateFrame: Closure to calculate viewport frame given constraints
    ///   - requestRecalculation: Closure called when recalculation is requested
    public init(
        core: PVEmulatorCore,
        calculateFrame: @escaping (CGSize, UIEdgeInsets, Bool) -> CGRect?,
        requestRecalculation: @escaping () -> Void = {}
    ) {
        self.core = core
        self.calculateFrame = calculateFrame
        self.requestRecalculation = requestRecalculation
        super.init()

        // Set this bridge as the layout provider
        core.viewportLayoutProvider = self
    }

    // MARK: - PVViewportLayoutProvider

    @objc public func calculateViewportFrame(
        containerSize: CGSize,
        safeInsets: UIEdgeInsets,
        isLandscape: Bool
    ) -> NSValue? {
        guard let frame = calculateFrame(containerSize, safeInsets, isLandscape) else {
            return nil
        }
        return NSValue(cgRect: frame)
    }

    @objc public func requestViewportRecalculation() {
        requestRecalculation()
    }

    /// Notify the delegate that a frame has been calculated
    /// Call this from SwiftUI views when they calculate a new frame
    public func notifyFrameUpdated(_ frame: CGRect) {
        core?.viewportLayoutDelegate?.viewportFrameDidUpdate(frame)
    }
}

/// SwiftUI view modifier to connect a view to the viewport layout protocol
struct ViewportLayoutProviderModifier: ViewModifier {
    let core: PVEmulatorCore
    let calculateFrame: (CGSize, EdgeInsets, Bool) -> CGRect?
    @State private var bridge: ViewportLayoutProviderBridge?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Create bridge when view appears
                bridge = ViewportLayoutProviderBridge(
                    core: core,
                    calculateFrame: { size, insets, isLandscape in
                        // Convert UIEdgeInsets to SwiftUI EdgeInsets
                        let edgeInsets = EdgeInsets(
                            top: insets.top,
                            leading: insets.left,
                            bottom: insets.bottom,
                            trailing: insets.right
                        )
                        return calculateFrame(size, edgeInsets, isLandscape)
                    },
                    requestRecalculation: {
                        // Trigger recalculation if needed
                    }
                )
            }
            .onDisappear {
                // Clean up bridge when view disappears
                bridge = nil
                core.viewportLayoutProvider = nil
            }
    }
}

extension View {
    /// Connect this view to the viewport layout protocol system
    /// - Parameters:
    ///   - core: The emulator core
    ///   - calculateFrame: Closure to calculate viewport frame
    func viewportLayoutProvider(
        core: PVEmulatorCore,
        calculateFrame: @escaping (CGSize, EdgeInsets, Bool) -> CGRect?
    ) -> some View {
        modifier(ViewportLayoutProviderModifier(core: core, calculateFrame: calculateFrame))
    }
}
