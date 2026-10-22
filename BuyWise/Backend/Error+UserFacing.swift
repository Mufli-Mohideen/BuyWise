import Foundation

extension Error {
    /// Returns the error message to show the user.
    var userFacingMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
