// CheatCodeValidator.swift
// PVUI
//
// Validates and auto-formats cheat codes for common retro-game cheat types.
// Supports Game Genie, GameShark, Action Replay, Code Breaker, Gecko, and more.

import Foundation
import SwiftUI

// MARK: - CheatCodeValidator

/// Validates and auto-formats cheat codes for retro-game cheat types such as
/// Game Genie, GameShark, Action Replay, Code Breaker, and Gecko.
public struct CheatCodeValidator {

    // MARK: - ValidationResult

    /// The outcome of validating a cheat code against its expected format.
    public enum ValidationResult: Equatable {
        case empty
        case valid
        case invalid(hint: String)

        /// `true` when the code is present and well-formed.
        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        /// The format hint shown when the code doesn't match. `nil` when valid or empty.
        public var errorHint: String? {
            if case .invalid(let hint) = self { return hint }
            return nil
        }
    }

    // MARK: - Private Descriptor

    private struct FormatDescriptor {
        let matchKey: String          // Substring matched in lowercased type string
        let placeholder: String       // TextField placeholder
        let exampleHint: String       // Human-readable format hint
        let validate: (String) -> Bool
        let autoFormat: ((String) -> String)?
    }

    // MARK: - Format Table

    private static let formats: [FormatDescriptor] = [
        // Gecko (Wii / GameCube) — XXXXXXXX XXXXXXXX, one pair per line
        .init(
            matchKey: "gecko",
            placeholder: "XXXXXXXX XXXXXXXX",
            exampleHint: "e.g. 04123456 DEADBEEF (one 8+8 hex pair per line)",
            validate: { linesMatch($0, patterns: ["^[A-F0-9]{8} [A-F0-9]{8}$"]) },
            autoFormat: nil
        ),

        // Game Genie — multiple sub-formats depending on system
        .init(
            matchKey: "game genie",
            placeholder: "XXXX-XXXX",
            exampleHint: "SNES/Genesis: XXXX-XXXX · NES: XXXXXX · GB: XXX-XXX-XXX",
            validate: { code in
                matchesFull(code, "^[A-Z]{6,8}$") ||
                matchesFull(code, "^[A-Z0-9]{4}-[A-Z0-9]{4}$") ||
                matchesFull(code, "^[A-Z0-9]{3}-[A-Z0-9]{3}-[A-Z0-9]{3}$")
            },
            autoFormat: { code in
                let clean = code.filter { $0.isLetter || $0.isNumber }
                // Auto-insert dash for 8-char SNES/Genesis style if no dash yet
                if clean.count == 8, !code.contains("-") {
                    let p1 = String(clean.prefix(4))
                    let p2 = String(clean.dropFirst(4))
                    return "\(p1)-\(p2)"
                }
                return code
            }
        ),

        // GameShark (all versions)
        .init(
            matchKey: "game shark",
            placeholder: "XXXXXXXX YYYY",
            exampleHint: "e.g. 8012544A 00FF (N64/PSX) or 01001DCD 0007 (GBA)",
            validate: { linesMatch($0, patterns: [
                "^[A-F0-9]{8} [A-F0-9]{4}$",
                "^[A-F0-9]{8} [A-F0-9]{8}$"
            ]) },
            autoFormat: { hexPairFormat($0, firstLen: 8) }
        ),

        // Pro Action Replay (any version)
        .init(
            matchKey: "action replay",
            placeholder: "XXXXXXXX XXXXXXXX",
            exampleHint: "e.g. D01234AB 00FF (8 hex + space + 4–8 hex value)",
            validate: { linesMatch($0, patterns: [
                "^[A-F0-9]{8} [A-F0-9]{4}$",
                "^[A-F0-9]{8} [A-F0-9]{8}$"
            ]) },
            autoFormat: { hexPairFormat($0, firstLen: 8) }
        ),

        // Code Breaker
        .init(
            matchKey: "code breaker",
            placeholder: "XXXXXXXX YYYY",
            exampleHint: "e.g. 1A2B3C4D 0001 (8 hex + space + 4 hex)",
            validate: { linesMatch($0, patterns: [
                "^[A-F0-9]{8} [A-F0-9]{4}$",
                "^[A-F0-9]{8} [A-F0-9]{8}$"
            ]) },
            autoFormat: { hexPairFormat($0, firstLen: 8) }
        ),

        // Gold Finger
        .init(
            matchKey: "gold finger",
            placeholder: "XXXXXXXXXX",
            exampleHint: "10-character hex code",
            validate: { matchesFull($0, "^[A-F0-9]{10}$") },
            autoFormat: nil
        ),

        // Raw / unknown — accept anything non-empty
        .init(
            matchKey: "raw",
            placeholder: "Enter code",
            exampleHint: "Raw cheat code — any format accepted",
            validate: { !$0.isEmpty },
            autoFormat: nil
        ),
    ]

    // MARK: - Public API

    /// TextField placeholder for the given cheat type.
    public static func placeholder(for type: String) -> String {
        descriptor(for: type)?.placeholder ?? "Enter cheat code"
    }

    /// Human-readable format hint for the given type, or `nil` for unknown types.
    public static func formatHint(for type: String) -> String? {
        descriptor(for: type)?.exampleHint
    }

    /// Validates `code` against the expected format for `type`.
    /// Returns `.empty` for blank input, `.valid` on success, or `.invalid(hint:)` on mismatch.
    public static func validate(_ code: String, for type: String) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let upper = trimmed.uppercased()
        guard let desc = descriptor(for: type) else { return .valid }
        return desc.validate(upper) ? .valid : .invalid(hint: desc.exampleHint)
    }

    /// Returns `code` uppercased with format-specific separators auto-inserted.
    public static func autoFormat(_ code: String, for type: String) -> String {
        let upper = code.uppercased()
        return descriptor(for: type)?.autoFormat?(upper) ?? upper
    }

    // MARK: - Private Helpers

    private static func descriptor(for type: String) -> FormatDescriptor? {
        let lower = type.lowercased()
        return formats.first { lower.contains($0.matchKey) }
    }

    /// `true` if every non-empty line of `code` matches at least one of the given patterns.
    private static func linesMatch(_ code: String, patterns: [String]) -> Bool {
        let lines = code.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { line in patterns.contains { matchesFull(line, $0) } }
    }

    /// Pre-compiled regex cache so patterns are not recompiled on every keystroke.
    private static let compiledPatterns: [String: NSRegularExpression] = {
        let patterns = [
            "^[A-F0-9]{8} [A-F0-9]{8}$",
            "^[A-Z]{6,8}$",
            "^[A-Z0-9]{4}-[A-Z0-9]{4}$",
            "^[A-Z0-9]{3}-[A-Z0-9]{3}-[A-Z0-9]{3}$",
            "^[A-F0-9]{8} [A-F0-9]{4}$",
            "^[A-F0-9]{10}$",
        ]
        return patterns.reduce(into: [:]) { dict, p in
            dict[p] = try? NSRegularExpression(pattern: p)
        }
    }()

    private static func matchesFull(_ string: String, _ pattern: String) -> Bool {
        guard let regex = compiledPatterns[pattern] else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }

    /// Auto-inserts a space after `firstLen` hex digits (e.g. "XXXXXXXX YYYY").
    private static func hexPairFormat(_ code: String, firstLen: Int) -> String {
        let digits = code.filter { $0.isHexDigit }
        guard digits.count > firstLen else { return String(digits) }
        let p1 = String(digits.prefix(firstLen))
        let p2 = String(digits.dropFirst(firstLen).prefix(firstLen))
        return "\(p1) \(p2)"
    }
}

// MARK: - onChange Compatibility

extension View {
    /// Bridges `onChange(of:perform:)` (iOS/tvOS ≤ 16) with `onChange(of:_:)` (17+).
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, tvOS 17.0, *) {
            self.onChange(of: value) { _, _ in action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}
