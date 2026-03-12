import Foundation

public enum GitBookPreprocessor {
    /// Apply all GitBook-to-standard-markdown transforms in sequence.
    public static func process(_ markdown: String) -> String {
        var result = stripFrontMatter(markdown)
        result = convertHintBlocks(result)
        result = convertTabBlocks(result)
        result = convertHTMLTables(result)
        result = convertHTMLDetailsBlocks(result)
        result = convertHTMLInlineTags(result)
        result = resolveImagePaths(result)
        return result
    }

    /// Remove YAML front matter (---\n...\n---) at the start of the file.
    public static func stripFrontMatter(_ markdown: String) -> String {
        guard markdown.hasPrefix("---") else { return markdown }
        let lines = markdown.components(separatedBy: "\n")
        // Find the closing --- (skip the first line which is the opening ---)
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                let remaining = lines[(i + 1)...].joined(separator: "\n")
                return remaining.trimmingCharacters(in: .newlines)
            }
        }
        return markdown
    }

    /// Convert GitBook hint blocks to blockquotes with emoji prefixes.
    /// Input:  {% hint style="info" %} text {% endhint %}
    /// Output: > info: text
    public static func convertHintBlocks(_ markdown: String) -> String {
        let pattern = #"\{%\s*hint\s+style="(\w+)"\s*%\}([\s\S]*?)\{%\s*endhint\s*%\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return markdown
        }

        let nsString = markdown as NSString
        var result = markdown
        // Process matches in reverse order to preserve ranges
        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let styleRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let style = nsString.substring(with: styleRange)
            let content = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            let emoji = hintEmoji(for: style)
            // Convert content lines to blockquote
            let quotedLines = content.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
            let replacement = "> \(emoji) **\(style.capitalized)**\n\(quotedLines)"

            result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
        }

        return result
    }

    /// Convert GitBook tab blocks to Markdown sections.
    ///
    /// - `{% tabs %}` and `{% endtabs %}` are removed.
    /// - `{% tab title="Title" %}` becomes `### Title`
    /// - `{% endtab %}` becomes a horizontal rule `---`
    /// - Any remaining `{% ... %}` liquid tags are stripped.
    public static func convertTabBlocks(_ markdown: String) -> String {
        var result = markdown

        // Remove {% tabs %} and {% endtabs %}
        result = result.replacingOccurrences(
            of: #"\{%\s*tabs\s*%\}"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{%\s*endtabs\s*%\}"#,
            with: "",
            options: .regularExpression
        )

        // Convert {% tab title="..." %} → ### Title
        let tabPattern = #"\{%\s*tab\s+title="([^"]+)"\s*%\}"#
        if let regex = try? NSRegularExpression(pattern: tabPattern, options: [.caseInsensitive]) {
            let nsResult = result as NSString
            let matches = regex.matches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: nsResult.length)
            )
            for match in matches.reversed() {
                let titleRange = match.range(at: 1)
                let title = nsResult.substring(with: titleRange)
                let replacement = "### \(title)"
                result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: replacement)
            }
        }

        // {% endtab %} → --- (visual separator between tabs)
        result = result.replacingOccurrences(
            of: #"\{%\s*endtab\s*%\}"#,
            with: "\n---\n",
            options: .regularExpression
        )

        // Strip any remaining {% ... %} liquid tags
        result = result.replacingOccurrences(
            of: #"\{%[^%]*%\}"#,
            with: "",
            options: .regularExpression
        )

        return result
    }

    /// Convert HTML `<table>` blocks to Markdown tables.
    public static func convertHTMLTables(_ markdown: String) -> String {
        let pattern = #"(?i)<table[^>]*>([\s\S]*?)</table>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return markdown
        }

        let nsString = markdown as NSString
        var result = markdown
        let matches = regex.matches(
            in: markdown,
            options: [],
            range: NSRange(location: 0, length: nsString.length)
        )

        for match in matches.reversed() {
            let tableContent = nsString.substring(with: match.range(at: 1))
            let markdownTable = htmlTableToMarkdown(tableContent)
            result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: markdownTable)
        }

        return result
    }

    private static func htmlTableToMarkdown(_ tableHTML: String) -> String {
        // Extract rows
        let rowPattern = #"(?i)<tr[^>]*>([\s\S]*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: []) else {
            return stripHTMLTags(tableHTML)
        }

        let nsTableString = tableHTML as NSString
        let rowMatches = rowRegex.matches(
            in: tableHTML,
            options: [],
            range: NSRange(location: 0, length: nsTableString.length)
        )

        var rows: [[String]] = []

        for rowMatch in rowMatches {
            let rowContent = nsTableString.substring(with: rowMatch.range(at: 1))

            // Extract cell content (th or td)
            let cellPattern = #"(?i)<t[hd][^>]*>([\s\S]*?)</t[hd]>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: []) else {
                continue
            }

            let nsRowString = rowContent as NSString
            let cellMatches = cellRegex.matches(
                in: rowContent,
                options: [],
                range: NSRange(location: 0, length: nsRowString.length)
            )

            let cells = cellMatches.map { cellMatch -> String in
                let rawCell = nsRowString.substring(with: cellMatch.range(at: 1))
                return stripHTMLTags(rawCell).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        guard !rows.isEmpty else { return "" }

        let colCount = rows.map { $0.count }.max() ?? 1
        var lines: [String] = []

        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())

        // Pad row to column count
        func paddedRow(_ row: [String]) -> String {
            let padded = row + Array(repeating: " ", count: max(0, colCount - row.count))
            return "| " + padded.map { $0.isEmpty ? " " : $0 }.joined(separator: " | ") + " |"
        }

        lines.append(paddedRow(headerRow))
        lines.append("|" + Array(repeating: " --- |", count: colCount).joined())
        for row in dataRows {
            lines.append(paddedRow(row))
        }

        return "\n" + lines.joined(separator: "\n") + "\n"
    }

    /// Convert HTML `<details>/<summary>` blocks to a bold heading + content.
    public static func convertHTMLDetailsBlocks(_ markdown: String) -> String {
        let pattern = #"(?i)<details[^>]*>\s*<summary[^>]*>([\s\S]*?)</summary>([\s\S]*?)</details>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return markdown
        }

        let nsString = markdown as NSString
        var result = markdown
        let matches = regex.matches(
            in: markdown,
            options: [],
            range: NSRange(location: 0, length: nsString.length)
        )

        for match in matches.reversed() {
            let summaryRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let summary = stripHTMLTags(nsString.substring(with: summaryRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let content = stripHTMLTags(nsString.substring(with: contentRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let replacement: String
            if content.isEmpty {
                replacement = "**\(summary)**"
            } else {
                replacement = "**\(summary)**\n\n\(content)"
            }

            result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
        }

        return result
    }

    /// Convert common inline HTML tags to Markdown equivalents, then strip remaining tags.
    public static func convertHTMLInlineTags(_ markdown: String) -> String {
        var result = markdown

        // <strong>...</strong> and <b>...</b> → **...**
        result = result.replacingOccurrences(
            of: #"(?i)<strong>([\s\S]*?)</strong>"#,
            with: "**$1**",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)<b>([\s\S]*?)</b>"#,
            with: "**$1**",
            options: .regularExpression
        )

        // <em>...</em> and <i>...</i> → *...*
        result = result.replacingOccurrences(
            of: #"(?i)<em>([\s\S]*?)</em>"#,
            with: "*$1*",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)<i>([\s\S]*?)</i>"#,
            with: "*$1*",
            options: .regularExpression
        )

        // <code>...</code> → `...`
        result = result.replacingOccurrences(
            of: #"(?i)<code>([\s\S]*?)</code>"#,
            with: "`$1`",
            options: .regularExpression
        )

        // <br> / <br/> → two spaces + newline (Markdown line break)
        result = result.replacingOccurrences(
            of: #"(?i)<br\s*/?>"#,
            with: "  \n",
            options: .regularExpression
        )

        // <p>...</p> → paragraph with trailing newlines
        result = result.replacingOccurrences(
            of: #"(?i)<p[^>]*>([\s\S]*?)</p>"#,
            with: "$1\n\n",
            options: .regularExpression
        )

        // Strip any remaining HTML tags
        result = stripHTMLTags(result)

        return result
    }

    /// Resolve relative image paths to absolute GitHub raw URLs.
    public static func resolveImagePaths(_ markdown: String) -> String {
        // Match ![alt](.gitbook/assets/...) or ![alt](../.gitbook/assets/...)
        let pattern = #"!\[([^\]]*)\]\((?:\.\./)*(\.gitbook/assets/[^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return markdown
        }

        let nsString = markdown as NSString
        var result = markdown
        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let altRange = match.range(at: 1)
            let pathRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let alt = nsString.substring(with: altRange)
            let path = nsString.substring(with: pathRange)
            let absoluteURL = WikiConstants.baseURL.appendingPathComponent(path).absoluteString
            let replacement = "![\(alt)](\(absoluteURL))"

            result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
        }

        return result
    }

    // MARK: - Helpers

    /// Strip all HTML tags from a string, preserving text content.
    static func stripHTMLTags(_ html: String) -> String {
        return html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    private static func hintEmoji(for style: String) -> String {
        switch style.lowercased() {
        case "info": return "\u{2139}\u{FE0F}" // info emoji
        case "success": return "\u{2705}" // checkmark
        case "warning": return "\u{26A0}\u{FE0F}" // warning
        case "danger": return "\u{1F6A8}" // danger
        default: return "\u{1F4DD}" // memo
        }
    }
}
