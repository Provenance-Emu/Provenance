import Foundation

/// The import queue owns its picker, independently of whichever sheet or cover presents the queue.
struct ImportDocumentSelection {
    var isPresented = false
    var errorMessage: String?

    mutating func begin() {
        errorMessage = nil
        isPresented = true
    }

    mutating func complete(_ result: Result<[URL], Error>) -> [URL] {
        isPresented = false
        switch result {
        case .success(let urls):
            errorMessage = nil
            return urls
        case .failure(let error):
            let cocoaError = error as NSError
            errorMessage = cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError
                ? nil : error.localizedDescription
            return []
        }
    }
}
