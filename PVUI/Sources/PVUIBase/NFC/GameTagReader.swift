//
//  GameTagReader.swift
//  PVUIBase
//
//  Reads one tag in the foreground and reports what it holds (see GameTagContent).
//  Tags read in the background never reach this class: iOS opens the universal link
//  and the app's normal URL route launches the game.
//

#if os(iOS) && canImport(CoreNFC)
import CoreNFC
import Foundation
import PVLogging

public final class GameTagReader: NSObject, NFCNDEFReaderSessionDelegate {
    /// Held strongly so the session's delegate outlives the view that started it.
    public static let shared = GameTagReader()

    /// False on devices without an NFC reader (iPad, Mac, simulator).
    public static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    private enum Message {
        static let prompt = "Hold your iPhone near a game tag."
        static let multipleTags = "More than one tag found. Remove all but one tag and try again."
        static let connectFailed = "Couldn't read the tag. Try again."
        static let notInLibrary = "This game isn't in your library."
        static func opening(_ title: String?) -> String {
            title.map { "Opening “\($0)”." } ?? "Opening game."
        }
    }

    /// Delay before polling again after several tags were in the field.
    private static let retryInterval: DispatchTimeInterval = .milliseconds(500)

    private var session: NFCNDEFReaderSession?
    private var isInLibrary: ((String) -> Bool)?
    private var open: ((String) -> Void)?
    /// Game to open once the NFC sheet has gone away.
    private var pendingMD5: String?

    /// Scans one tag. For a Provenance game tag whose game `isInLibrary`, calls `open` with
    /// the MD5; every other outcome is reported in the NFC sheet. Both closures run on the
    /// main thread. Must be called on the main thread.
    public func scan(isInLibrary: @escaping (String) -> Bool, open: @escaping (String) -> Void) {
        guard Self.isAvailable else {
            WLOG("GameTagReader: NFC reading is not available on this device")
            return
        }
        session?.invalidate()
        self.isInLibrary = isInLibrary
        self.open = open
        pendingMD5 = nil
        let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session.alertMessage = Message.prompt
        self.session = session
        session.begin()
    }

    // MARK: NFCNDEFReaderSessionDelegate

    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    /// Required by the protocol; never called because `didDetect tags:` is implemented.
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        GameTagSessionError.log(error, context: "GameTagReader")
        guard session === self.session else { return }
        let md5 = pendingMD5
        let open = self.open
        self.session = nil
        isInLibrary = nil
        self.open = nil
        pendingMD5 = nil
        // Open after the sheet is dismissed so the game scene isn't presented under it.
        if let md5 { open?(md5) }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = Message.multipleTags
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) {
                session.restartPolling()
            }
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                ELOG("GameTagReader: connect failed: \(error.localizedDescription)")
                session.invalidate(errorMessage: Message.connectFailed)
                return
            }
            tag.readNDEF { message, error in
                let content: GameTagContent
                if let message {
                    content = GameTagPayload.content(of: message.records.map(GameTagRecord.init))
                } else if let readerError = error as? NFCReaderError,
                          readerError.code == .ndefReaderSessionErrorZeroLengthMessage {
                    content = .empty
                } else {
                    ELOG("GameTagReader: read failed: \(error?.localizedDescription ?? "no message")")
                    session.invalidate(errorMessage: Message.connectFailed)
                    return
                }
                self?.finish(session, with: content)
            }
        }
    }

    private func finish(_ session: NFCNDEFReaderSession, with content: GameTagContent) {
        ILOG("GameTagReader: read \(content)")
        guard case let .game(md5, title) = content else {
            session.invalidate(errorMessage: content.failureMessage ?? Message.connectFailed)
            return
        }
        guard isInLibrary?(md5) == true else {
            session.invalidate(errorMessage: Message.notInLibrary)
            return
        }
        pendingMD5 = md5
        session.alertMessage = Message.opening(title)
        session.invalidate()
    }
}
#endif
