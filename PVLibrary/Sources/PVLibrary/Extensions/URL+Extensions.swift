/// Extension to provide pathDecoded property for URL
extension URL {
    /// Returns the path of the URL with percent encoding removed
    /// This is useful when working with file paths that may contain special characters
    var pathDecoded: String {
        /// Decode the path component of the URL to handle special characters
        return path(percentEncoded: false)
    }
}
