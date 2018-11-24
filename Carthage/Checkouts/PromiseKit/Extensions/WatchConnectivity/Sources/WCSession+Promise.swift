import WatchConnectivity
import Foundation
#if !PMKCocoaPods
import PromiseKit
#endif


@available(iOS 9.0, *)
@available(iOSApplicationExtension 9.0, *)
extension WCSession {

    /// Sends a message immediately to the paired and active device and optionally handles a response.
    public func sendMessage(_ message: [String: Any]) -> Promise<[String: Any]> {
        return Promise { sendMessage(message, replyHandler: $0.fulfill, errorHandler: $0.reject) }
    }

    /// Sends a data object immediately to the paired and active device and optionally handles a response.
    public func sendMessageData(_ data: Data) -> Promise<Data> {
        return Promise { sendMessageData(data, replyHandler: $0.fulfill, errorHandler: $0.reject) }
    }
}
