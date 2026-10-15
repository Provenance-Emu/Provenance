//
//  GameTagWriter.swift
//  PVUIBase
//
//  Writes a game tag (see GameTagPayload) with an NDEF reader session.
//  Tags are left writable: the session never calls writeLock.
//

#if os(iOS) && canImport(CoreNFC)
import CoreNFC
import Foundation
import PVLogging

public final class GameTagWriter: NSObject, NFCNDEFReaderSessionDelegate {
    /// Held strongly so the session's delegate outlives the menu that started it.
    public static let shared = GameTagWriter()

    /// False on devices without an NFC reader (iPad, Mac, simulator).
    public static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    private enum Message {
        static func prompt(_ title: String) -> String { "Hold your iPhone near an NFC tag to write “\(title)”." }
        static func written(_ title: String) -> String { "Tag written. Tap it with your iPhone to play “\(title)”." }
        static let multipleTags = "More than one tag found. Remove all but one tag and try again."
        static let connectFailed = "Couldn't connect to the tag. Try again."
        static let notNDEF = "This tag can't store a game link."
        static let readOnly = "This tag is locked and can't be written."
        static let tooSmall = "This tag is too small to hold a game link."
        static let writeFailed = "Couldn't write the tag. Try again."
    }

    /// Delay before polling again after several tags were in the field.
    private static let retryInterval: DispatchTimeInterval = .milliseconds(500)

    private var session: NFCNDEFReaderSession?
    private var payload: GameTagPayload?

    /// Starts a write session for `payload`. Must be called on the main thread.
    public func write(_ payload: GameTagPayload) {
        guard Self.isAvailable else {
            WLOG("GameTagWriter: NFC reading is not available on this device")
            return
        }
        session?.invalidate()
        self.payload = payload
        let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session.alertMessage = Message.prompt(payload.title)
        self.session = session
        session.begin()
    }

    // MARK: NFCNDEFReaderSessionDelegate

    /// Required by the protocol; never called because `didDetect tags:` is implemented.
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        GameTagSessionError.log(error, context: "GameTagWriter")
        guard session === self.session else { return }
        self.session = nil
        payload = nil
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = Message.multipleTags
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) {
                session.restartPolling()
            }
            return
        }
        guard let payload else {
            session.invalidate()
            return
        }

        session.connect(to: tag) { error in
            if let error {
                ELOG("GameTagWriter: connect failed: \(error.localizedDescription)")
                session.invalidate(errorMessage: Message.connectFailed)
                return
            }
            tag.queryNDEFStatus { status, capacity, error in
                if let error {
                    ELOG("GameTagWriter: status query failed: \(error.localizedDescription)")
                    session.invalidate(errorMessage: Message.connectFailed)
                    return
                }
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: Message.notNDEF)
                case .readOnly:
                    session.invalidate(errorMessage: Message.readOnly)
                case .readWrite:
                    Self.write(payload, to: tag, capacity: capacity, session: session)
                @unknown default:
                    session.invalidate(errorMessage: Message.notNDEF)
                }
            }
        }
    }

    private static func write(_ payload: GameTagPayload, to tag: NFCNDEFTag, capacity: Int, session: NFCNDEFReaderSession) {
        guard let records = payload.records(fittingCapacity: capacity) else {
            session.invalidate(errorMessage: Message.tooSmall)
            return
        }
        let message = NFCNDEFMessage(records: records.map(\.nfcPayload))
        tag.writeNDEF(message) { error in
            if let error {
                ELOG("GameTagWriter: write failed: \(error.localizedDescription)")
                session.invalidate(errorMessage: Message.writeFailed)
                return
            }
            ILOG("GameTagWriter: wrote \(payload.launchURL.absoluteString) (\(records.count) records, capacity \(capacity))")
            session.alertMessage = Message.written(payload.title)
            session.invalidate()
        }
    }
}

// MARK: - CoreNFC bridging

extension GameTagRecord {
    init(_ payload: NFCNDEFPayload) {
        self.init(typeNameFormat: payload.typeNameFormat.rawValue,
                  type: payload.type,
                  identifier: payload.identifier,
                  payload: payload.payload)
    }

    var nfcPayload: NFCNDEFPayload {
        NFCNDEFPayload(format: NFCTypeNameFormat(rawValue: typeNameFormat) ?? .unknown,
                       type: type,
                       identifier: identifier,
                       payload: payload)
    }
}

enum GameTagSessionError {
    /// Logs a session invalidation. Cancels, timeouts and the normal end of a session are not failures.
    static func log(_ error: Error, context: String) {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerSessionInvalidationErrorUserCanceled,
                 .readerSessionInvalidationErrorFirstNDEFTagRead,
                 .readerSessionInvalidationErrorSessionTimeout:
                DLOG("\(context): session ended (\(readerError.code.rawValue))")
                return
            default:
                break
            }
        }
        ELOG("\(context): session invalidated: \(error.localizedDescription)")
    }
}
#endif
