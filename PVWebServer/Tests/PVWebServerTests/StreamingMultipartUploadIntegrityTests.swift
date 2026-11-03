import Foundation
import Hummingbird
import XCTest
@testable import PVWebServer

final class StreamingMultipartUploadIntegrityTests: XCTestCase {
    func testPreservesBinaryPayloadAcrossHeaderToBodyTransition() async throws {
        let payload = Data((0..<65_552).map { UInt8($0 % 256) })
        try await assertRoundTrip(payload: payload, initialPayloadCount: 1_024, splitHeaders: false)
    }

    func testPreservesShortBodyPrefixAfterSplitHeaders() async throws {
        let payload = Data((0..<128).map(UInt8.init))
        try await assertRoundTrip(payload: payload, initialPayloadCount: 16, splitHeaders: true)
    }

    func testPreservesSingleChunkUpload() async throws {
        let payload = Data([0, 255, 13, 10, 128, 0, 42])
        try await assertRoundTrip(payload: payload, initialPayloadCount: payload.count, splitHeaders: false)
    }

    private func assertRoundTrip(payload: Data, initialPayloadCount: Int, splitHeaders: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let boundary = "0123456789abcdef0123456789abcdef"
        let headers = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"probe.rom\"\r\n\r\n".utf8)
        let closing = Data("\r\n--\(boundary)--\r\n".utf8)
        var chunks: [Data] = []
        if splitHeaders { chunks.append(Data(headers.prefix(23))) }
        var first = splitHeaders ? Data(headers.dropFirst(23)) : headers
        first.append(payload.prefix(initialPayloadCount))
        if initialPayloadCount == payload.count {
            first.append(closing)
            chunks.append(first)
        } else {
            chunks.append(first)
            var last = Data(payload.dropFirst(initialPayloadCount))
            last.append(closing)
            chunks.append(last)
        }
        let body = RequestBody(asyncSequence: AsyncStream<ByteBuffer> { continuation in
            for chunk in chunks { continuation.yield(ByteBuffer(bytes: chunk)) }
            continuation.finish()
        })
        let result = try await StreamingMultipartUpload.streamSingleFilePart(
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            uploadDirectory: root,
            resolvePath: { name, directory in directory.appendingPathComponent(name) }
        )
        XCTAssertEqual(result.bytesWritten, Int64(payload.count))
        XCTAssertEqual(try Data(contentsOf: result.destination), payload)
    }
}
