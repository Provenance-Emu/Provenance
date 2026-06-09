//
//  WebDAVPropertyBuilder.swift
//  PVWebServer
//
//  WebDAV PROPFIND XML fragments (testable, Finder-compatible).
//

import Foundation

enum WebDAVPropertyBuilder {

    /// ISO8601 creation date for WebDAV `creationdate` (UTC).
    static func iso8601CreationDate(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return fmt.string(from: date)
    }

    /// RFC822 last-modified string for WebDAV `getlastmodified`.
    static func rfc822LastModified(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        fmt.timeZone = TimeZone(abbreviation: "GMT")
        return fmt.string(from: date)
    }

    /// Lightweight etag from size + modification time.
    static func etag(size: Int, modified: Date?) -> String {
        let ts = modified.map { String($0.timeIntervalSince1970) } ?? "0"
        return "\"\(size)-\(ts)\""
    }

    /// Builds one `<D:response>` block for PROPFIND multistatus payloads.
    static func propfindResponseBlock(
        href: String,
        isDirectory: Bool,
        size: Int,
        modified: Date?,
        created: Date?
    ) -> String {
        let escapedHref = href.xmlEscaped
        let resourceType = isDirectory ? "<D:collection/>" : ""
        let mtime = modified.map { rfc822LastModified($0) } ?? ""
        let ctime = created.map { iso8601CreationDate($0) } ?? (modified.map { iso8601CreationDate($0) } ?? "")
        let tag = etag(size: size, modified: modified)

        return """
            <D:response>
                <D:href>\(escapedHref)</D:href>
                <D:propstat>
                    <D:prop>
                        <D:resourcetype>\(resourceType)</D:resourcetype>
                        <D:creationdate>\(ctime)</D:creationdate>
                        <D:getlastmodified>\(mtime)</D:getlastmodified>
                        <D:getcontentlength>\(size)</D:getcontentlength>
                        <D:getetag>\(tag)</D:getetag>
                        <D:supportedlock>
                            <D:lockentry>
                                <D:lockscope><D:exclusive/></D:lockscope>
                                <D:locktype><D:write/></D:locktype>
                            </D:lockentry>
                        </D:supportedlock>
                    </D:prop>
                    <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
            </D:response>
        """
    }
}

extension String {
    /// Escape XML special characters for WebDAV multistatus bodies.
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
