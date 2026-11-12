//
//  RetroArchOverlayConfig.swift
//  PVSettings
//
//  The part of a RetroArch overlay `.cfg` that matters for a bezel.
//

import Foundation

/// A RetroArch overlay configuration, read for use as a bezel around the picture.
///
/// The format is `key = value` lines; a value may be quoted and `#` starts a comment. A bezel
/// overlay names one image and has no buttons. An overlay with buttons is a touch-control
/// layout, which is not a bezel.
public struct RetroArchOverlayConfig: Equatable, Sendable {

    public enum ParseError: Error, Equatable {
        /// The overlay has buttons (`overlay0_descs`): it is a touch-control layout.
        case touchControls(buttons: Int)
        /// No `overlay0_overlay`: the file names no image.
        case noImage
    }

    enum Key {
        static let count = "overlays"
        static let image = "overlay0_overlay"
        static let name = "overlay0_name"
        static let buttons = "overlay0_descs"
        static let fullScreen = "overlay0_full_screen"
        static let rect = "overlay0_rect"
    }

    /// File name of the first overlay's image, without any folder it was written with.
    public let imageName: String
    /// The overlay's own name, when it has one.
    public let displayName: String?
    /// How many overlays the file holds. Only the first is used.
    public let overlayCount: Int
    /// `overlay0_full_screen`. Read, not used: the image is always fitted whole to the display.
    public let isFullScreen: Bool?
    /// `overlay0_rect` (x, y, width, height as fractions). Read, not used.
    public let rect: CGRect?

    public init(text: String) throws {
        let values = Self.values(in: text)
        let buttons = values[Key.buttons].flatMap { Int($0) } ?? 0
        guard buttons <= 0 else { throw ParseError.touchControls(buttons: buttons) }
        guard let image = values[Key.image].map(Self.lastPathComponent), !image.isEmpty else {
            throw ParseError.noImage
        }
        imageName = image
        displayName = values[Key.name].flatMap { $0.isEmpty ? nil : $0 }
        overlayCount = max(values[Key.count].flatMap { Int($0) } ?? 1, 1)
        isFullScreen = values[Key.fullScreen].flatMap(Self.bool)
        rect = values[Key.rect].flatMap(Self.rect)
    }

    /// Every `key = value` pair of a RetroArch config file. A later line replaces an earlier one.
    public static func values(in text: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value(String(trimmed[trimmed.index(after: equals)...]))
        }
        return values
    }

    /// The value of one line: the quoted text, or everything up to a comment.
    private static func value(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\"") {
            let body = trimmed.dropFirst()
            return String(body.prefix { $0 != "\"" })
        }
        let uncommented = trimmed.prefix { $0 != "#" }
        return uncommented.trimmingCharacters(in: .whitespaces)
    }

    /// The file name of a path written with either kind of slash.
    private static func lastPathComponent(_ path: String) -> String {
        String(path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last ?? "")
    }

    private static func bool(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }

    private static func rect(_ text: String) -> CGRect? {
        let parts = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }
}
