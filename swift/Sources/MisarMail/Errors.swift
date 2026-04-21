/// Errors thrown by ``MisarMailClient``.
public enum MisarMailError: Error, CustomStringConvertible {

    /// The API returned a non-2xx HTTP response.
    ///
    /// - Parameters:
    ///   - status:  HTTP status code.
    ///   - message: Human-readable description from the API response body.
    case apiError(status: Int, message: String)

    /// A network-level error prevented the request from completing, or the
    /// maximum number of retries was exhausted.
    ///
    /// - Parameter message: Underlying error description.
    case networkError(message: String)

    public var description: String {
        switch self {
        case .apiError(let status, let message):
            return "MisarMailError.apiError(\(status)): \(message)"
        case .networkError(let message):
            return "MisarMailError.networkError: \(message)"
        }
    }
}
