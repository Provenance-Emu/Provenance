//
//  CDFileHandler.swift
//  PVLibrary
//
//  Created by David Proskin on 11/14/24.
//

import Foundation
import PVPrimitives

protocol CDFileHandling {
    func parseCueSheet(cueFileURL: URL) throws -> [String]
    func candidateBinUrls(for binFileNames:[String], in directories: [URL]) -> [URL]
    func parseM3U(from url: URL) throws -> [String]
    func fileExistsAtPath(_ path: URL) -> Bool
    func cleanCueFile(at url: URL) throws
}

class DefaultCDFileHandler: CDFileHandling {

    func parseCueSheet(cueFileURL: URL) throws -> [String] {
        // Try to read with multiple encodings to handle encoding issues
        let cueContents = try readCueFileWithEncodingFallback(cueFileURL: cueFileURL)
        let lines = cueContents.components(separatedBy: .newlines)

        // Array to hold file names
        var fileNames: [String] = []

        // Look for each line like: FILE "filename.ext" SOME_TYPE
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ensure the line starts with FILE (case-insensitive) and has quotes for the filename
            if trimmedLine.uppercased().hasPrefix("FILE") {
                // Normalize quotes and extract filename
                let normalizedLine = normalizeCueLine(trimmedLine)
                if normalizedLine.contains("\"") {
                    let components = normalizedLine.components(separatedBy: "\"")
                    // The filename should be the second component, e.g., after the first quote
                    if components.count >= 2 {
                        let fileName = components[1].trimmingCharacters(in: .whitespaces)
                        // Basic validation: ensure filename is not empty and seems reasonable (e.g., has an extension)
                        if !fileName.isEmpty && fileName.contains(".") {
                            fileNames.append(fileName)
                        }
                    }
                }
            }
        }

        // Return the file names
        return fileNames
    }

    /// Reads a CUE file trying multiple encodings to handle encoding issues
    private func readCueFileWithEncodingFallback(cueFileURL: URL) throws -> String {
        let encodings: [String.Encoding] = [.utf8, .windowsCP1252, .isoLatin1, .macOSRoman]

        for encoding in encodings {
            if let contents = try? String(contentsOf: cueFileURL, encoding: encoding) {
                return contents
            }
        }

        // Fallback to UTF-8 and let it throw if it fails
        return try String(contentsOf: cueFileURL, encoding: .utf8)
    }

    /// Normalizes a CUE line by fixing quote issues and cleaning up malformed FILE lines
    private func normalizeCueLine(_ line: String) -> String {
        var normalized = line

        // Fix corrupted quote patterns (UTF-8 quotes misread as Windows-1252)
        normalized = normalized.replacingOccurrences(of: "‚Äù", with: "\"") // Corrupted right quote
        normalized = normalized.replacingOccurrences(of: "‚Äú", with: "\"") // Corrupted left quote

        // Replace smart quotes and other quote variants with regular quotes
        normalized = normalized.replacingOccurrences(of: "\u{201C}", with: "\"") // Left double quotation mark
        normalized = normalized.replacingOccurrences(of: "\u{201D}", with: "\"") // Right double quotation mark
        normalized = normalized.replacingOccurrences(of: "\u{201E}", with: "\"") // Double low-9 quotation mark
        normalized = normalized.replacingOccurrences(of: "\u{201F}", with: "\"") // Double high-reversed-9 quotation mark
        normalized = normalized.replacingOccurrences(of: "\u{2033}", with: "\"") // Double prime
        normalized = normalized.replacingOccurrences(of: "\u{2036}", with: "\"") // Reversed double prime

        // Fix FILE lines where "BINARY" or other keywords are incorrectly included in the filename
        // Pattern: FILE "filename.ext" BINARY -> FILE "filename.ext" BINARY
        // But sometimes it's: FILE "filename.ext BINARY" -> FILE "filename.ext" BINARY
        if normalized.uppercased().hasPrefix("FILE") {
            // Use regex to properly extract filename and type
            let pattern = #"FILE\s+"([^"]+)"\s*(\w+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = normalized as NSString
                if let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let filenameRange = match.range(at: 1)
                    let typeRange = match.range(at: 2)

                    if filenameRange.location != NSNotFound && typeRange.location != NSNotFound {
                        let filename = nsString.substring(with: filenameRange)
                        let type = nsString.substring(with: typeRange)

                        // Clean filename - remove any trailing keywords that shouldn't be there
                        var cleanFilename = filename.trimmingCharacters(in: .whitespaces)
                        let keywordsToRemove = ["BINARY", "MOTOROLA", "AIFF", "WAVE", "MP3"]
                        for keyword in keywordsToRemove {
                            if cleanFilename.uppercased().hasSuffix(" " + keyword.uppercased()) {
                                cleanFilename = String(cleanFilename.dropLast(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
                            }
                        }

                        return "FILE \"\(cleanFilename)\" \(type)"
                    }
                }
            }
        }

        return normalized
    }

    func candidateBinUrls(for binFileNames:[String], in directories: [URL]) -> [URL] {
        // Array to hold potential .bin file URLs
        var binFiles: [URL] = []

        for binFileName in binFileNames {
            for directory in directories {
                binFiles.append(directory.appendingPathComponent(binFileName))
            }
        }

        // Return all possible .bin file URLs
        return binFiles
    }


    func parseM3U(from url: URL) throws -> [String] {
        // Read the M3U file content
        let contents = try String(contentsOf: url, encoding: .utf8)

        // Handle different line endings (CR, LF, CRLF) by normalizing to newlines
        let normalizedContents = contents.replacingOccurrences(of: "\r\n", with: "\n")
                                         .replacingOccurrences(of: "\r", with: "\n")

        // Extract file paths, ignoring comments and empty lines
        let files = normalizedContents.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { self.normalizeFilePath($0) }

        return files
    }

    /// Normalize a file path from an M3U file to handle relative paths and ensure consistent format
    private func normalizeFilePath(_ path: String) -> String {
        // Extract just the filename if it contains path separators
        if path.contains("/") || path.contains("\\") {
            let components = path.components(separatedBy: CharacterSet(charactersIn: "/\\"))
            if let fileName = components.last, !fileName.isEmpty {
                return fileName
            }
        }
        return path
    }

    func fileExistsAtPath(_ path: URL) -> Bool {
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Cleans and normalizes a CUE file to fix encoding issues, quote problems, and malformed FILE lines
    func cleanCueFile(at url: URL) throws {
        // Read the file with encoding fallback
        let originalContents = try readCueFileWithEncodingFallback(cueFileURL: url)
        let lines = originalContents.components(separatedBy: .newlines)

        var cleanedLines: [String] = []
        var hasChanges = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            if trimmedLine.isEmpty {
                cleanedLines.append("")
                continue
            }

            // Normalize the line
            let normalizedLine = normalizeCueLine(trimmedLine)

            // Check if FILE line needs fixing
            if normalizedLine.uppercased().hasPrefix("FILE") {
                // Ensure proper format: FILE "filename.ext" TYPE
                let fixedLine = fixCueFileLine(normalizedLine)
                if fixedLine != trimmedLine {
                    hasChanges = true
                    cleanedLines.append(fixedLine)
                } else {
                    cleanedLines.append(normalizedLine)
                }
            } else {
                // For non-FILE lines, just normalize quotes
                if normalizedLine != trimmedLine {
                    hasChanges = true
                    cleanedLines.append(normalizedLine)
                } else {
                    cleanedLines.append(trimmedLine)
                }
            }
        }

        // Only write if there were changes
        if hasChanges {
            let cleanedContents = cleanedLines.joined(separator: "\n")
            // Ensure file ends with newline if original did
            let finalContents = originalContents.hasSuffix("\n") ? cleanedContents + "\n" : cleanedContents

            // Write back with UTF-8 encoding
            try finalContents.write(to: url, atomically: true, encoding: .utf8)
            ILOG("Cleaned CUE file: \(url.lastPathComponent)")
        }
    }

    /// Fixes a FILE line in a CUE file to ensure proper format
    private func fixCueFileLine(_ line: String) -> String {
        var workingLine = line.trimmingCharacters(in: .whitespaces)

        // Ensure it starts with FILE
        guard workingLine.uppercased().hasPrefix("FILE") else {
            return line
        }

        // Remove "FILE" prefix and trim
        let afterFile = String(workingLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)

        // Find the filename in quotes
        guard let firstQuoteRange = afterFile.range(of: "\"") else {
            return line
        }

        let afterFirstQuote = String(afterFile[firstQuoteRange.upperBound...])
        guard let secondQuoteRange = afterFirstQuote.range(of: "\"") else {
            return line
        }

        let filename = String(afterFirstQuote[..<secondQuoteRange.lowerBound])
        let afterFilename = String(afterFirstQuote[secondQuoteRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Clean filename - remove any keywords that shouldn't be there
        var cleanFilename = filename.trimmingCharacters(in: .whitespaces)

        // Fix corrupted quote patterns (e.g., ‚Äù which is UTF-8 quote misread as Windows-1252)
        cleanFilename = cleanFilename.replacingOccurrences(of: "‚Äù", with: "")
        cleanFilename = cleanFilename.replacingOccurrences(of: "‚Äú", with: "")
        cleanFilename = cleanFilename.trimmingCharacters(in: .whitespaces)

        let keywordsToRemove = ["BINARY", "MOTOROLA", "AIFF", "WAVE", "MP3"]
        for keyword in keywordsToRemove {
            let upperKeyword = keyword.uppercased()
            if cleanFilename.uppercased().hasSuffix(" " + upperKeyword) {
                cleanFilename = String(cleanFilename.dropLast(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
            }
            // Also check if keyword is at the end without space
            if cleanFilename.uppercased().hasSuffix(upperKeyword) && cleanFilename.count > keyword.count {
                // Make sure it's not part of the actual filename (e.g., "BINARY.bin" should keep "BINARY")
                let beforeKeyword = String(cleanFilename.dropLast(keyword.count))
                if beforeKeyword.hasSuffix(" ") || beforeKeyword.isEmpty {
                    cleanFilename = beforeKeyword.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Determine the type (BINARY, MOTOROLA, AIFF, WAVE, MP3)
        var fileType = "BINARY" // Default
        let upperAfterFilename = afterFilename.uppercased()
        if upperAfterFilename.contains("BINARY") {
            fileType = "BINARY"
        } else if upperAfterFilename.contains("MOTOROLA") {
            fileType = "MOTOROLA"
        } else if upperAfterFilename.contains("AIFF") {
            fileType = "AIFF"
        } else if upperAfterFilename.contains("WAVE") || upperAfterFilename.contains("WAV") {
            fileType = "WAVE"
        } else if upperAfterFilename.contains("MP3") {
            fileType = "MP3"
        }

        return "FILE \"\(cleanFilename)\" \(fileType)"
    }
}
