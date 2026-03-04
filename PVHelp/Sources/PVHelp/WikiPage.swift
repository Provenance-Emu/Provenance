import Foundation

public struct WikiPage: Sendable {
    public let path: String
    public let title: String
    public let content: String

    public init(path: String, title: String, content: String) {
        self.path = path
        self.title = title
        self.content = content
    }
}
