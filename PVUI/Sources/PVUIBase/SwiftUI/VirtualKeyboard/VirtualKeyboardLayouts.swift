// VirtualKeyboardLayouts.swift
// PVUI
//
// Platform-specific virtual keyboard layouts for home computer emulation.
// Supports standard QWERTY, Commodore 64, ZX Spectrum, and Amstrad CPC layouts.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import GameController

// MARK: - VirtualKey

/// A single key in the virtual keyboard overlay.
public struct VirtualKey: Identifiable, Sendable {
    public let id: UUID
    /// The label displayed on the key.
    public let label: String
    /// The `GCKeyCode` sent when this key is pressed.
    public let keyCode: GCKeyCode
    /// Whether this key is a sticky modifier (toggles on/off).
    public let isModifier: Bool
    /// Visual width multiplier relative to a standard key.
    public let widthMultiplier: CGFloat
    /// Optional SF Symbol name for the key icon.
    public let symbolName: String?

    public init(
        label: String,
        keyCode: GCKeyCode,
        isModifier: Bool = false,
        widthMultiplier: CGFloat = 1.0,
        symbolName: String? = nil
    ) {
        self.id = UUID()
        self.label = label
        self.keyCode = keyCode
        self.isModifier = isModifier
        self.widthMultiplier = widthMultiplier
        self.symbolName = symbolName
    }
}

// MARK: - VirtualKeyboardLayout

/// Available virtual keyboard layout styles.
public enum VirtualKeyboardLayout: String, CaseIterable, Identifiable, Sendable {
    /// Standard full QWERTY layout with number row and modifiers.
    case full
    /// Compact layout: letters plus essential keys only.
    case compact
    /// Function key row: F1-F12 strip only.
    case functionRow
    /// Commodore 64 keyboard layout.
    case c64
    /// ZX Spectrum keyboard layout with CAPS SHIFT and SYMBOL SHIFT sticky modifiers.
    case zxSpectrum
    /// Amstrad CPC keyboard layout with CPC function keys f0-f9.
    case amstradCPC

    public var id: String { rawValue }

    /// Human-readable display name for toolbar picker.
    public var displayName: String {
        switch self {
        case .full:        return "Full"
        case .compact:     return "Compact"
        case .functionRow: return "Fn Row"
        case .c64:         return "C64"
        case .zxSpectrum:  return "Spectrum"
        case .amstradCPC:  return "CPC"
        }
    }

    /// Returns the rows of keys for this layout.
    public var rows: [[VirtualKey]] {
        switch self {
        case .full:        return VirtualKeyboardLayouts.fullLayout
        case .compact:     return VirtualKeyboardLayouts.compactLayout
        case .functionRow: return VirtualKeyboardLayouts.functionRowLayout
        case .c64:         return VirtualKeyboardLayouts.c64Layout
        case .zxSpectrum:  return VirtualKeyboardLayouts.zxSpectrumLayout
        case .amstradCPC:  return VirtualKeyboardLayouts.amstradCPCLayout
        }
    }
}

// MARK: - VirtualKeyboardLayouts

/// Static definitions for each keyboard layout's key rows.
public enum VirtualKeyboardLayouts {

    // MARK: Standard Full QWERTY

    public static let fullLayout: [[VirtualKey]] = [
        // Number row
        [
            .init(label: "ESC",  keyCode: .escape,             symbolName: "escape"),
            .init(label: "1",    keyCode: .one),
            .init(label: "2",    keyCode: .two),
            .init(label: "3",    keyCode: .three),
            .init(label: "4",    keyCode: .four),
            .init(label: "5",    keyCode: .five),
            .init(label: "6",    keyCode: .six),
            .init(label: "7",    keyCode: .seven),
            .init(label: "8",    keyCode: .eight),
            .init(label: "9",    keyCode: .nine),
            .init(label: "0",    keyCode: .zero),
            .init(label: "DEL",  keyCode: .deleteOrBackspace,  widthMultiplier: 1.5, symbolName: "delete.left"),
        ],
        // Function row
        [
            .init(label: "F1",  keyCode: .F1),
            .init(label: "F2",  keyCode: .F2),
            .init(label: "F3",  keyCode: .F3),
            .init(label: "F4",  keyCode: .F4),
            .init(label: "F5",  keyCode: .F5),
            .init(label: "F6",  keyCode: .F6),
            .init(label: "F7",  keyCode: .F7),
            .init(label: "F8",  keyCode: .F8),
            .init(label: "F9",  keyCode: .F9),
            .init(label: "F10", keyCode: .F10),
            .init(label: "F11", keyCode: .F11),
            .init(label: "F12", keyCode: .F12),
        ],
        // QWERTY row
        [
            .init(label: "TAB", keyCode: .tab,          widthMultiplier: 1.5, symbolName: "arrow.right.to.line"),
            .init(label: "Q",   keyCode: .keyQ),
            .init(label: "W",   keyCode: .keyW),
            .init(label: "E",   keyCode: .keyE),
            .init(label: "R",   keyCode: .keyR),
            .init(label: "T",   keyCode: .keyT),
            .init(label: "Y",   keyCode: .keyY),
            .init(label: "U",   keyCode: .keyU),
            .init(label: "I",   keyCode: .keyI),
            .init(label: "O",   keyCode: .keyO),
            .init(label: "P",   keyCode: .keyP),
            .init(label: "RET", keyCode: .returnOrEnter, widthMultiplier: 1.5, symbolName: "return"),
        ],
        // ASDF row
        [
            .init(label: "CTRL", keyCode: .leftControl, isModifier: true, widthMultiplier: 1.5, symbolName: "control"),
            .init(label: "A",    keyCode: .keyA),
            .init(label: "S",    keyCode: .keyS),
            .init(label: "D",    keyCode: .keyD),
            .init(label: "F",    keyCode: .keyF),
            .init(label: "G",    keyCode: .keyG),
            .init(label: "H",    keyCode: .keyH),
            .init(label: "J",    keyCode: .keyJ),
            .init(label: "K",    keyCode: .keyK),
            .init(label: "L",    keyCode: .keyL),
            .init(label: ";",    keyCode: .semicolon),
            .init(label: "'",    keyCode: .quote),
        ],
        // ZXCV row
        [
            .init(label: "SHF",  keyCode: .leftShift,  isModifier: true, widthMultiplier: 2.0, symbolName: "shift"),
            .init(label: "Z",    keyCode: .keyZ),
            .init(label: "X",    keyCode: .keyX),
            .init(label: "C",    keyCode: .keyC),
            .init(label: "V",    keyCode: .keyV),
            .init(label: "B",    keyCode: .keyB),
            .init(label: "N",    keyCode: .keyN),
            .init(label: "M",    keyCode: .keyM),
            .init(label: ",",    keyCode: .comma),
            .init(label: ".",    keyCode: .period),
            .init(label: "UP",   keyCode: .upArrow,    symbolName: "arrow.up"),
            .init(label: "SHF",  keyCode: .rightShift, isModifier: true, symbolName: "shift"),
        ],
        // Bottom row
        [
            .init(label: "ALT",   keyCode: .leftAlt,   isModifier: true, symbolName: "option"),
            .init(label: "SPACE", keyCode: .spacebar,  widthMultiplier: 4.0),
            .init(label: "LT",    keyCode: .leftArrow,  symbolName: "arrow.left"),
            .init(label: "DN",    keyCode: .downArrow,  symbolName: "arrow.down"),
            .init(label: "RT",    keyCode: .rightArrow, symbolName: "arrow.right"),
        ],
    ]

    // MARK: Compact QWERTY

    public static let compactLayout: [[VirtualKey]] = [
        [
            .init(label: "Q", keyCode: .keyQ),
            .init(label: "W", keyCode: .keyW),
            .init(label: "E", keyCode: .keyE),
            .init(label: "R", keyCode: .keyR),
            .init(label: "T", keyCode: .keyT),
            .init(label: "Y", keyCode: .keyY),
            .init(label: "U", keyCode: .keyU),
            .init(label: "I", keyCode: .keyI),
            .init(label: "O", keyCode: .keyO),
            .init(label: "P", keyCode: .keyP),
        ],
        [
            .init(label: "A",   keyCode: .keyA),
            .init(label: "S",   keyCode: .keyS),
            .init(label: "D",   keyCode: .keyD),
            .init(label: "F",   keyCode: .keyF),
            .init(label: "G",   keyCode: .keyG),
            .init(label: "H",   keyCode: .keyH),
            .init(label: "J",   keyCode: .keyJ),
            .init(label: "K",   keyCode: .keyK),
            .init(label: "L",   keyCode: .keyL),
            .init(label: "DEL", keyCode: .deleteOrBackspace, symbolName: "delete.left"),
        ],
        [
            .init(label: "SHF", keyCode: .leftShift,    isModifier: true, symbolName: "shift"),
            .init(label: "Z",   keyCode: .keyZ),
            .init(label: "X",   keyCode: .keyX),
            .init(label: "C",   keyCode: .keyC),
            .init(label: "V",   keyCode: .keyV),
            .init(label: "B",   keyCode: .keyB),
            .init(label: "N",   keyCode: .keyN),
            .init(label: "M",   keyCode: .keyM),
            .init(label: "RET", keyCode: .returnOrEnter, widthMultiplier: 1.5, symbolName: "return"),
        ],
        [
            .init(label: "CTRL",  keyCode: .leftControl, isModifier: true, symbolName: "control"),
            .init(label: "SPACE", keyCode: .spacebar,    widthMultiplier: 4.0),
            .init(label: "ESC",   keyCode: .escape,      symbolName: "escape"),
        ],
    ]

    // MARK: Function Row

    public static let functionRowLayout: [[VirtualKey]] = [
        [
            .init(label: "ESC", keyCode: .escape, symbolName: "escape"),
            .init(label: "F1",  keyCode: .F1),
            .init(label: "F2",  keyCode: .F2),
            .init(label: "F3",  keyCode: .F3),
            .init(label: "F4",  keyCode: .F4),
            .init(label: "F5",  keyCode: .F5),
            .init(label: "F6",  keyCode: .F6),
            .init(label: "F7",  keyCode: .F7),
            .init(label: "F8",  keyCode: .F8),
            .init(label: "F9",  keyCode: .F9),
            .init(label: "F10", keyCode: .F10),
            .init(label: "F11", keyCode: .F11),
            .init(label: "F12", keyCode: .F12),
        ],
    ]

    // MARK: Commodore 64

    public static let c64Layout: [[VirtualKey]] = [
        // Row 1
        [
            .init(label: "LT-ARR",   keyCode: .graveAccentAndTilde),
            .init(label: "1",         keyCode: .one),
            .init(label: "2",         keyCode: .two),
            .init(label: "3",         keyCode: .three),
            .init(label: "4",         keyCode: .four),
            .init(label: "5",         keyCode: .five),
            .init(label: "6",         keyCode: .six),
            .init(label: "7",         keyCode: .seven),
            .init(label: "8",         keyCode: .eight),
            .init(label: "9",         keyCode: .nine),
            .init(label: "0",         keyCode: .zero),
            .init(label: "+",         keyCode: .equalSign),
            .init(label: "-",         keyCode: .hyphen),
            .init(label: "GBP",       keyCode: .scrollLock),
            .init(label: "CLR HOME",  keyCode: .home,              widthMultiplier: 1.5),
            .init(label: "INST DEL",  keyCode: .deleteOrBackspace,  widthMultiplier: 1.5, symbolName: "delete.left"),
        ],
        // Row 2
        [
            .init(label: "CTRL",     keyCode: .leftControl, isModifier: true, widthMultiplier: 1.5, symbolName: "control"),
            .init(label: "Q",        keyCode: .keyQ),
            .init(label: "W",        keyCode: .keyW),
            .init(label: "E",        keyCode: .keyE),
            .init(label: "R",        keyCode: .keyR),
            .init(label: "T",        keyCode: .keyT),
            .init(label: "Y",        keyCode: .keyY),
            .init(label: "U",        keyCode: .keyU),
            .init(label: "I",        keyCode: .keyI),
            .init(label: "O",        keyCode: .keyO),
            .init(label: "P",        keyCode: .keyP),
            .init(label: "@",        keyCode: .openBracket),
            .init(label: "*",        keyCode: .closeBracket),
            .init(label: "UP",       keyCode: .upArrow,     symbolName: "arrow.up"),
            .init(label: "RESTORE",  keyCode: .printScreen,  widthMultiplier: 1.5),
        ],
        // Row 3
        [
            .init(label: "RUN STOP", keyCode: .escape,        widthMultiplier: 1.5),
            .init(label: "A",        keyCode: .keyA),
            .init(label: "S",        keyCode: .keyS),
            .init(label: "D",        keyCode: .keyD),
            .init(label: "F",        keyCode: .keyF),
            .init(label: "G",        keyCode: .keyG),
            .init(label: "H",        keyCode: .keyH),
            .init(label: "J",        keyCode: .keyJ),
            .init(label: "K",        keyCode: .keyK),
            .init(label: "L",        keyCode: .keyL),
            .init(label: ":",        keyCode: .semicolon),
            .init(label: ";",        keyCode: .quote),
            .init(label: "=",        keyCode: .nonUSPound),
            .init(label: "RETURN",   keyCode: .returnOrEnter, widthMultiplier: 2.0, symbolName: "return"),
        ],
        // Row 4
        [
            .init(label: "C=",       keyCode: .leftGUI,    isModifier: true, widthMultiplier: 1.5),
            .init(label: "SHIFT",    keyCode: .leftShift,  isModifier: true, widthMultiplier: 1.5, symbolName: "shift"),
            .init(label: "Z",        keyCode: .keyZ),
            .init(label: "X",        keyCode: .keyX),
            .init(label: "C",        keyCode: .keyC),
            .init(label: "V",        keyCode: .keyV),
            .init(label: "B",        keyCode: .keyB),
            .init(label: "N",        keyCode: .keyN),
            .init(label: "M",        keyCode: .keyM),
            .init(label: ",",        keyCode: .comma),
            .init(label: ".",        keyCode: .period),
            .init(label: "/",        keyCode: .slash),
            .init(label: "SHIFT",    keyCode: .rightShift, isModifier: true, widthMultiplier: 1.5, symbolName: "shift"),
            .init(label: "CRSR DN",  keyCode: .downArrow,  symbolName: "arrow.down"),
            .init(label: "CRSR RT",  keyCode: .rightArrow, symbolName: "arrow.right"),
        ],
        // Row 5: F keys
        [
            .init(label: "F1", keyCode: .F1),
            .init(label: "F2", keyCode: .F2),
            .init(label: "F3", keyCode: .F3),
            .init(label: "F4", keyCode: .F4),
            .init(label: "F5", keyCode: .F5),
            .init(label: "F6", keyCode: .F6),
            .init(label: "F7", keyCode: .F7),
            .init(label: "F8", keyCode: .F8),
        ],
        // Row 6: Space
        [
            .init(label: "SPACE", keyCode: .spacebar, widthMultiplier: 8.0),
        ],
    ]

    // MARK: ZX Spectrum

    public static let zxSpectrumLayout: [[VirtualKey]] = [
        // Row 1: 1-0
        [
            .init(label: "1", keyCode: .one),
            .init(label: "2", keyCode: .two),
            .init(label: "3", keyCode: .three),
            .init(label: "4", keyCode: .four),
            .init(label: "5", keyCode: .five),
            .init(label: "6", keyCode: .six),
            .init(label: "7", keyCode: .seven),
            .init(label: "8", keyCode: .eight),
            .init(label: "9", keyCode: .nine),
            .init(label: "0", keyCode: .zero),
        ],
        // Row 2: Q-P
        [
            .init(label: "Q", keyCode: .keyQ),
            .init(label: "W", keyCode: .keyW),
            .init(label: "E", keyCode: .keyE),
            .init(label: "R", keyCode: .keyR),
            .init(label: "T", keyCode: .keyT),
            .init(label: "Y", keyCode: .keyY),
            .init(label: "U", keyCode: .keyU),
            .init(label: "I", keyCode: .keyI),
            .init(label: "O", keyCode: .keyO),
            .init(label: "P", keyCode: .keyP),
        ],
        // Row 3: A-ENTER
        [
            .init(label: "A",     keyCode: .keyA),
            .init(label: "S",     keyCode: .keyS),
            .init(label: "D",     keyCode: .keyD),
            .init(label: "F",     keyCode: .keyF),
            .init(label: "G",     keyCode: .keyG),
            .init(label: "H",     keyCode: .keyH),
            .init(label: "J",     keyCode: .keyJ),
            .init(label: "K",     keyCode: .keyK),
            .init(label: "L",     keyCode: .keyL),
            .init(label: "ENTER", keyCode: .returnOrEnter, widthMultiplier: 1.5, symbolName: "return"),
        ],
        // Row 4: CAPS SHIFT, Z-M, SYMBOL SHIFT, SPACE
        [
            .init(label: "CAPS SHF",  keyCode: .leftShift, isModifier: true, widthMultiplier: 1.75, symbolName: "shift"),
            .init(label: "Z",         keyCode: .keyZ),
            .init(label: "X",         keyCode: .keyX),
            .init(label: "C",         keyCode: .keyC),
            .init(label: "V",         keyCode: .keyV),
            .init(label: "B",         keyCode: .keyB),
            .init(label: "N",         keyCode: .keyN),
            .init(label: "M",         keyCode: .keyM),
            .init(label: "SYM SHF",   keyCode: .leftAlt,   isModifier: true, widthMultiplier: 1.75, symbolName: "option"),
            .init(label: "SPACE",     keyCode: .spacebar,  widthMultiplier: 2.0),
        ],
        // Row 5: Arrow keys + BREAK
        [
            .init(label: "LT",    keyCode: .leftArrow,       symbolName: "arrow.left"),
            .init(label: "DN",    keyCode: .downArrow,       symbolName: "arrow.down"),
            .init(label: "UP",    keyCode: .upArrow,         symbolName: "arrow.up"),
            .init(label: "RT",    keyCode: .rightArrow,      symbolName: "arrow.right"),
            .init(label: "DEL",   keyCode: .deleteOrBackspace, symbolName: "delete.left"),
            .init(label: "BREAK", keyCode: .pause,           widthMultiplier: 1.5),
        ],
    ]

    // MARK: Amstrad CPC

    public static let amstradCPCLayout: [[VirtualKey]] = [
        // Row 1
        [
            .init(label: "ESC",  keyCode: .escape,       symbolName: "escape"),
            .init(label: "1",    keyCode: .one),
            .init(label: "2",    keyCode: .two),
            .init(label: "3",    keyCode: .three),
            .init(label: "4",    keyCode: .four),
            .init(label: "5",    keyCode: .five),
            .init(label: "6",    keyCode: .six),
            .init(label: "7",    keyCode: .seven),
            .init(label: "8",    keyCode: .eight),
            .init(label: "9",    keyCode: .nine),
            .init(label: "0",    keyCode: .zero),
            .init(label: "-",    keyCode: .hyphen),
            .init(label: "=",    keyCode: .equalSign),
            .init(label: "DEL",  keyCode: .deleteForward,  widthMultiplier: 1.5, symbolName: "delete.forward"),
            .init(label: "CLR",  keyCode: .home,           widthMultiplier: 1.5),
        ],
        // Row 2
        [
            .init(label: "TAB",    keyCode: .tab,          widthMultiplier: 1.5, symbolName: "arrow.right.to.line"),
            .init(label: "Q",      keyCode: .keyQ),
            .init(label: "W",      keyCode: .keyW),
            .init(label: "E",      keyCode: .keyE),
            .init(label: "R",      keyCode: .keyR),
            .init(label: "T",      keyCode: .keyT),
            .init(label: "Y",      keyCode: .keyY),
            .init(label: "U",      keyCode: .keyU),
            .init(label: "I",      keyCode: .keyI),
            .init(label: "O",      keyCode: .keyO),
            .init(label: "P",      keyCode: .keyP),
            .init(label: "[",      keyCode: .openBracket),
            .init(label: "]",      keyCode: .closeBracket),
            .init(label: "RETURN", keyCode: .returnOrEnter, widthMultiplier: 1.5, symbolName: "return"),
            .init(label: "CPY",    keyCode: .pageUp),
        ],
        // Row 3
        [
            .init(label: "CAPS",   keyCode: .capsLock,     isModifier: true, widthMultiplier: 1.5, symbolName: "capslock"),
            .init(label: "A",      keyCode: .keyA),
            .init(label: "S",      keyCode: .keyS),
            .init(label: "D",      keyCode: .keyD),
            .init(label: "F",      keyCode: .keyF),
            .init(label: "G",      keyCode: .keyG),
            .init(label: "H",      keyCode: .keyH),
            .init(label: "J",      keyCode: .keyJ),
            .init(label: "K",      keyCode: .keyK),
            .init(label: "L",      keyCode: .keyL),
            .init(label: ";",      keyCode: .semicolon),
            .init(label: ":",      keyCode: .quote),
            .init(label: "@",      keyCode: .backslash),
        ],
        // Row 4
        [
            .init(label: "SHIFT",  keyCode: .leftShift,  isModifier: true, widthMultiplier: 1.75, symbolName: "shift"),
            .init(label: "Z",      keyCode: .keyZ),
            .init(label: "X",      keyCode: .keyX),
            .init(label: "C",      keyCode: .keyC),
            .init(label: "V",      keyCode: .keyV),
            .init(label: "B",      keyCode: .keyB),
            .init(label: "N",      keyCode: .keyN),
            .init(label: "M",      keyCode: .keyM),
            .init(label: ",",      keyCode: .comma),
            .init(label: ".",      keyCode: .period),
            .init(label: "/",      keyCode: .slash),
            .init(label: "BSLSH",  keyCode: .nonUSBackslash),
            .init(label: "SHIFT",  keyCode: .rightShift, isModifier: true, widthMultiplier: 1.75, symbolName: "shift"),
            .init(label: "UP",     keyCode: .upArrow,    symbolName: "arrow.up"),
        ],
        // Row 5
        [
            .init(label: "CTRL",   keyCode: .leftControl, isModifier: true, symbolName: "control"),
            .init(label: "SPACE",  keyCode: .spacebar,    widthMultiplier: 5.0),
            .init(label: "ALT",    keyCode: .leftAlt,     isModifier: true, symbolName: "option"),
            .init(label: "DEL",    keyCode: .deleteOrBackspace, symbolName: "delete.left"),
            .init(label: "LT",     keyCode: .leftArrow,   symbolName: "arrow.left"),
            .init(label: "DN",     keyCode: .downArrow,   symbolName: "arrow.down"),
            .init(label: "RT",     keyCode: .rightArrow,  symbolName: "arrow.right"),
        ],
        // Row 6: CPC function keys f0-f9 (mapped to F1-F10)
        [
            .init(label: "f0", keyCode: .F1),
            .init(label: "f1", keyCode: .F2),
            .init(label: "f2", keyCode: .F3),
            .init(label: "f3", keyCode: .F4),
            .init(label: "f4", keyCode: .F5),
            .init(label: "f5", keyCode: .F6),
            .init(label: "f6", keyCode: .F7),
            .init(label: "f7", keyCode: .F8),
            .init(label: "f8", keyCode: .F9),
            .init(label: "f9", keyCode: .F10),
        ],
        // Row 7: Numeric keypad
        [
            .init(label: "7",  keyCode: .keypad7),
            .init(label: "8",  keyCode: .keypad8),
            .init(label: "9",  keyCode: .keypad9),
            .init(label: "4",  keyCode: .keypad4),
            .init(label: "5",  keyCode: .keypad5),
            .init(label: "6",  keyCode: .keypad6),
            .init(label: "1",  keyCode: .keypad1),
            .init(label: "2",  keyCode: .keypad2),
            .init(label: "3",  keyCode: .keypad3),
            .init(label: "0",  keyCode: .keypad0,     widthMultiplier: 2.0),
            .init(label: ".",  keyCode: .keypadPeriod),
            .init(label: "ENT", keyCode: .keypadEnter, symbolName: "return"),
        ],
    ]
}
