//
//  PaletteProviding.swift
//  PVCoreBridge
//
//  Part of #2649 — Custom Palette System
//  Sub-task 1: PaletteProviding protocol + CorePalette model
//

import Foundation

// MARK: - CorePalette

/// A named palette with 2–4 preview colors shown as a swatch in the palette picker.
///
/// Colors are stored as normalised RGB floats (0.0–1.0) ordered lightest→darkest,
/// matching the convention used by Game Boy and Virtual Boy cores.
public struct CorePalette: Identifiable, Hashable, Sendable {
    /// Stable identifier; must be unique within a given core's `availablePalettes`.
    public let id: String
    /// Human-readable palette name shown in the picker UI.
    public let displayName: String
    /// 2–4 colours forming the visual swatch. Order: lightest to darkest.
    public let colors: [PaletteColor]

    public init(id: String, displayName: String, colors: [PaletteColor]) {
        self.id = id
        self.displayName = displayName
        self.colors = colors
    }
}

// MARK: - PaletteColor

/// A single sRGB colour used in a palette swatch preview.
public struct PaletteColor: Sendable, Hashable {
    public let red: Float
    public let green: Float
    public let blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Initialise from a packed 24-bit hex value (e.g. `0x9BBD0F`).
    public init(hex: UInt32) {
        red   = Float((hex >> 16) & 0xFF) / 255.0
        green = Float((hex >> 8)  & 0xFF) / 255.0
        blue  = Float( hex        & 0xFF) / 255.0
    }
}

// MARK: - PaletteProviding

/// Adopted by emulator cores that expose a user-selectable palette.
///
/// The conformer is responsible for applying the palette to the running emulation;
/// the UI only calls `selectPalette(id:)` and reads `currentPaletteID` to determine
/// the current selection.
///
/// ## Adoption checklist
/// 1. Populate `availablePalettes` with every palette the core supports.
/// 2. Return the `id` of the active palette from `currentPaletteID`.
/// 3. In `selectPalette(id:)`, locate the palette by id and apply it to the core.
///
/// ## Example
/// ```swift
/// extension MyEmulatorCore: PaletteProviding {
///     public var availablePalettes: [CorePalette] { MyPalette.allCases.map(\.asCorepalette) }
///     public var currentPaletteID: String { displayMode.id }
///     public func selectPalette(id: String) {
///         guard let p = MyPalette.allCases.first(where: { $0.id == id }) else { return }
///         displayMode = p
///     }
/// }
/// ```
public protocol PaletteProviding: AnyObject {
    /// All palettes available for selection in this core.
    var availablePalettes: [CorePalette] { get }

    /// The `id` of the currently active palette.
    var currentPaletteID: String { get }

    /// Switch the active palette to the one with the given `id`.
    /// A no-op if `id` is not found in `availablePalettes`.
    func selectPalette(id: String)
}

// MARK: - Default helpers

extension PaletteProviding {
    /// Returns the `CorePalette` whose `id` matches `currentPaletteID`, or `nil`.
    public var currentPalette: CorePalette? {
        availablePalettes.first { $0.id == currentPaletteID }
    }

    /// Advance to the next palette, wrapping around to the first when at the end.
    public func cycleToNextPalette() {
        guard !availablePalettes.isEmpty else { return }
        let currentIndex = availablePalettes.firstIndex { $0.id == currentPaletteID } ?? -1
        let nextIndex = (currentIndex + 1) % availablePalettes.count
        selectPalette(id: availablePalettes[nextIndex].id)
    }
}
