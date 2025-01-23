import Foundation
import PVPrimitives

protocol CheatParser {
    associatedtype Entry: CheatEntry
    static func parse(_ contents: String, gameTitle: String) throws -> [Entry]
}

enum CheatFileParser<Driver: CheatDriver>: CheatParser {
    enum Error: LocalizedError {
        case invalidFormat
        case noValidCheats

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "The file format is invalid"
            case .noValidCheats:
                return "No valid cheats found in file"
            }
        }
    }

    static func parse(_ contents: String, gameTitle: String) throws -> [Driver.Entry] {
        var cheats: [Driver.Entry] = []
        var currentTitle: String?
        var currentCode: String?
        var currentType: String?

        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous cheat if we have one
                if let title = currentTitle,
                   let code = currentCode,
                   let detectedType = CheatCodeTypes.detectType(from: code).first {
                    let cheat = Driver.Entry(
                        id: UUID().uuidString,
                        code: code,
                        type: detectedType,
                        title: title,
                        enabled: false,
                        gameTitle: gameTitle
                    )
                    cheats.append(cheat)
                }

                // Start new cheat
                currentTitle = String(trimmed.dropFirst().dropLast())
                currentCode = nil
                currentType = nil
            } else if trimmed.lowercased().hasPrefix("code=") {
                currentCode = String(trimmed.dropFirst(5))
            } else if trimmed.lowercased().hasPrefix("type=") {
                currentType = String(trimmed.dropFirst(5))
            }
        }

        // Add final cheat
        if let title = currentTitle,
           let code = currentCode,
           let detectedType = CheatCodeTypes.detectType(from: code).first {
            let cheat = Driver.Entry(
                id: UUID().uuidString,
                code: code,
                type: detectedType,
                title: title,
                enabled: false,
                gameTitle: gameTitle
            )
            cheats.append(cheat)
        }

        guard !cheats.isEmpty else {
            throw Error.noValidCheats
        }

        return cheats
    }
}
