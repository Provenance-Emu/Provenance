/*
 PackageBuildInfoGenerator.swift — generates packageBuildInfo.swift; git stderr is discarded.
*/
import Foundation

@main
enum Entry {
    static func main() throws {
        var args = CommandLine.arguments
        args.removeFirst()
        guard args.count >= 2 else {
            fputs("Usage: PackageBuildInfo <repoRoot> <output.swift>\n", stderr)
            throw ExitCode.failure
        }
        let repoRoot = URL(fileURLWithPath: args[0], isDirectory: true)
        let outputURL = URL(fileURLWithPath: args[1])
        let content = try generateSwift(repoRoot: repoRoot)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)?.write(to: outputURL, options: .atomic)
    }
}

enum ExitCode: Error {
    case failure
}

/// Runs `git` with stderr sent to `/dev/null` so diagnostic noise never pollutes parsed stdout.
private func git(_ arguments: [String], repoRoot: URL) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = repoRoot
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

private func generateSwift(repoRoot: URL) throws -> String {
    let inside = try git(["rev-parse", "--is-inside-work-tree"], repoRoot: repoRoot)
    guard inside == "true" else {
        return template(
            isDirty: false,
            timeStamp: Date(),
            secondsFromGMT: TimeZone.current.secondsFromGMT(),
            count: 0,
            tagLiteral: "nil",
            countSinceTag: 0,
            branchLiteral: "nil",
            digestBytes: Array(repeating: 0, count: 20)
        )
    }

    let dirtyOut = try git(["status", "--porcelain"], repoRoot: repoRoot)
    let isDirty = !dirtyOut.isEmpty

    let ctStr = try git(["log", "-1", "--format=%ct"], repoRoot: repoRoot)
    let timeStamp: Date = {
        if let t = TimeInterval(ctStr), t > 0 { return Date(timeIntervalSince1970: t) }
        return Date()
    }()

    let zStr = try git(["log", "-1", "--format=%z"], repoRoot: repoRoot)
    let secondsFromGMT: Int = {
        guard zStr.count >= 5 else { return TimeZone.current.secondsFromGMT() }
        let sign: Int = zStr.hasPrefix("-") ? -1 : 1
        let digits = zStr.filter { $0.isNumber }
        guard digits.count >= 4,
              let hh = Int(digits.prefix(2)),
              let mm = Int(digits.dropFirst(2).prefix(2)) else { return TimeZone.current.secondsFromGMT() }
        return sign * (hh * 3600 + mm * 60)
    }()

    let countStr = try git(["rev-list", "--count", "HEAD"], repoRoot: repoRoot)
    let count = Int(countStr) ?? 0

    var tag: String?
    let exactTag = try git(["describe", "--tags", "--exact-match", "HEAD"], repoRoot: repoRoot)
    if !exactTag.isEmpty {
        tag = exactTag
    } else {
        let nearest = try git(["describe", "--tags", "--abbrev=0"], repoRoot: repoRoot)
        if !nearest.isEmpty { tag = nearest }
    }

    var countSinceTag = 0
    if let tag {
        let range = "\(tag)..HEAD"
        let sinceStr = try git(["rev-list", "--count", range], repoRoot: repoRoot)
        countSinceTag = Int(sinceStr) ?? 0
    }

    let branch = try git(["rev-parse", "--abbrev-ref", "HEAD"], repoRoot: repoRoot)
    let branchLiteral: String
    if branch.isEmpty || branch == "HEAD" {
        branchLiteral = "nil"
    } else {
        branchLiteral = swiftOptionalString(branch)
    }

    let tagLiteral: String
    if let tag {
        tagLiteral = swiftOptionalString(tag)
    } else {
        tagLiteral = "nil"
    }

    let sha = try git(["rev-parse", "HEAD"], repoRoot: repoRoot)
    let digestBytes: [UInt8] = parseHexSHA(sha) ?? Array(repeating: 0, count: 20)

    return template(
        isDirty: isDirty,
        timeStamp: timeStamp,
        secondsFromGMT: secondsFromGMT,
        count: count,
        tagLiteral: tagLiteral,
        countSinceTag: countSinceTag,
        branchLiteral: branchLiteral,
        digestBytes: digestBytes
    )
}

private func parseHexSHA(_ sha: String) -> [UInt8]? {
    let hex = sha.filter { $0.isHexDigit }
    guard hex.count == 40 else { return nil }
    var out: [UInt8] = []
    out.reserveCapacity(20)
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        let pair = hex[i..<j]
        guard let b = UInt8(pair, radix: 16) else { return nil }
        out.append(b)
        i = j
    }
    return out.count == 20 ? out : nil
}

private func swiftOptionalString(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

private func template(
    isDirty: Bool,
    timeStamp: Date,
    secondsFromGMT: Int,
    count: Int,
    tagLiteral: String,
    countSinceTag: Int,
    branchLiteral: String,
    digestBytes: [UInt8]
) -> String {
    let ts = String(format: "%.0f", timeStamp.timeIntervalSince1970)
    let digestList = digestBytes.map { String(format: "0x%02x", $0) }.joined(separator: ", ")
    return """
    /*
     Package Build info — code generated by PackageBuildInfo. DO NOT EDIT.
    */
    import Foundation

    public struct PackageBuild {
        public let isDirty: Bool
        public let timeStamp: Date
        public let timeZone: TimeZone
        public let count: Int
        public let tag: String?
        public let countSinceTag: Int
        public let branch: String?
        public let digest: [UInt8]

        public var commit: String {
            digest.reduce("") { $0 + String(format: "%02x", $1) }
        }
        public static let info = PackageBuild(
                              isDirty: \(isDirty),
                              timeStamp: Date(timeIntervalSince1970: \(ts)),
                              timeZone: TimeZone(secondsFromGMT: \(secondsFromGMT)) ?? TimeZone.current,
                              count: \(count),
                              tag: \(tagLiteral),
                              countSinceTag: \(countSinceTag),
                              branch: \(branchLiteral),
                              digest: [\(digestList)])
    }

    """
}
