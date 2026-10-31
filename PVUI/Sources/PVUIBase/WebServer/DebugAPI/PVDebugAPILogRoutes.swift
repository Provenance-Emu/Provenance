import Foundation
import PVLogging
#if canImport(PVWebServer)
import PVWebServer

/// Read-only snapshots served through the existing Debug API's enablement and authentication gates.
enum PVDebugAPILogRoutes {
    static let defaultLimit = 200
    static let maximumLimit = 1_000
    static let maximumResponseBytes = 256 * 1_024
    private static let envelopeReserveBytes = 2 * 1_024
    private static let maximumMessageBytes = 4 * 1_024
    private static let maximumCategoryBytes = 128

    static func register(
        in registry: PVDebugAPIRegistry,
        snapshot: @escaping @Sendable () -> [LogEntry] = { PVLogPublisher.shared.getRecentLogs() }
    ) {
        registry.register("GET", "/api/debug/logs") { request in
            response(query: request.query, entries: snapshot())
        }
    }

    static func response(query: [String: String], entries: [LogEntry]) -> PVDebugAPIResponse {
        let limit: Int
        if let raw = query["limit"] {
            guard let requested = Int(raw), requested > 0 else {
                return .error("limit must be a positive integer")
            }
            limit = min(requested, maximumLimit)
        } else {
            limit = defaultLimit
        }

        let minimumLevel: LogLevel
        switch query["level"]?.lowercased() ?? "verbose" {
        case "verbose": minimumLevel = .verbose
        case "debug": minimumLevel = .debug
        case "info": minimumLevel = .info
        case "warning": minimumLevel = .warning
        case "error": minimumLevel = .error
        default: return .error("level must be verbose, debug, info, warning, or error")
        }

        let category = query["category"]
        guard (category?.utf8.count ?? 0) <= maximumCategoryBytes else {
            return .error("category is too long")
        }
        let matching = entries.filter {
            $0.level >= minimumLevel && (category == nil || $0.category.caseInsensitiveCompare(category ?? "") == .orderedSame)
        }
        let candidates = matching.suffix(limit).reversed()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var rows: [[String: Any]] = []
        var rowBytes = 0
        for entry in candidates {
            let message = truncated(entry.message, maximumBytes: maximumMessageBytes)
            let row: [String: Any] = [
                "id": entry.id.uuidString,
                "timestamp": formatter.string(from: entry.timestamp),
                "level": entry.level.name.lowercased(),
                "category": truncated(entry.category, maximumBytes: maximumCategoryBytes),
                "message": message,
                "messageTruncated": message != entry.message,
            ]
            // Count JSON's escaped bytes, not String characters; control characters can expand sixfold.
            guard let encoded = try? JSONSerialization.data(withJSONObject: row),
                  rowBytes + encoded.count + 1 <= maximumResponseBytes - envelopeReserveBytes else { break }
            rowBytes += encoded.count + 1
            rows.append(row)
        }

        var payload: [String: Any] = [
            "entries": rows,
            "order": "newestFirst",
            "limit": limit,
            "retainedCount": entries.count,
            "matchingCount": matching.count,
            "returnedCount": rows.count,
            "limitApplied": matching.count > limit,
            "responseTruncated": rows.count < candidates.count,
            "retention": "recentMemoryBuffer",
            "earlierEntriesMayBeUnavailable": true,
            "capturedAt": formatter.string(from: Date()),
            "oldestRetained": NSNull(),
            "newestRetained": NSNull(),
        ]
        if let oldest = entries.first { payload["oldestRetained"] = formatter.string(from: oldest.timestamp) }
        if let newest = entries.last { payload["newestRetained"] = formatter.string(from: newest.timestamp) }
        return .ok(payload)
    }

    private static func truncated(_ value: String, maximumBytes: Int) -> String {
        guard value.utf8.count > maximumBytes else { return value }
        var bytes = Array(value.utf8.prefix(maximumBytes))
        // Drop at most the incomplete final UTF-8 scalar, keeping the response valid Unicode.
        while !bytes.isEmpty {
            if let result = String(bytes: bytes, encoding: .utf8) { return result }
            bytes.removeLast()
        }
        return ""
    }
}
#endif
