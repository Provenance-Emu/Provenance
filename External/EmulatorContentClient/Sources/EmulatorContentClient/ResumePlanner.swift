import Foundation

/// How a client should continue a partial content download.
public enum DownloadInstruction: Equatable, Sendable {
    case append(offset: Int64)
    case restart
    case notModified
    case unsatisfiable
}

public struct ResumePlan: Equatable, Sendable {
    public let offset: Int64
    public let range: String?

    /// Plans the next request from bytes already stored in a `.part` file.
    public static func plan(localBytes: Int64, totalBytes: Int64?) -> ResumePlan {
        if localBytes < 0 || (totalBytes.map { localBytes > $0 } ?? false) {
            return ResumePlan(offset: 0, range: nil)
        }
        if localBytes == 0 {
            return ResumePlan(offset: 0, range: nil)
        }
        return ResumePlan(offset: localBytes, range: "bytes=\(localBytes)-")
    }
}

/// Interprets a content response.
///
/// A `200` received after a ranged resume means the server ignored `Range`.
/// The partial file must be discarded before the body is written.
public func interpretDownload(statusCode: Int, requestedOffset: Int64) -> DownloadInstruction {
    switch statusCode {
    case 304:
        return .notModified
    case 416:
        return .unsatisfiable
    case 200 where requestedOffset > 0:
        return .restart
    case 200, 206:
        return .append(offset: requestedOffset)
    default:
        return .restart
    }
}
