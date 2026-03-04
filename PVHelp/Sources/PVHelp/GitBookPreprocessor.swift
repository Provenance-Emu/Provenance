import Foundation

public enum GitBookPreprocessor {
    /// Apply all GitBook-to-standard-markdown transforms in sequence.
    public static func process(_ markdown: String) -> String {
        var result = stripFrontMatter(markdown)
        result = convertHintBlocks(result)
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
