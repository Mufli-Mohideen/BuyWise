import Foundation

extension Error {
    /// The backend's own message when it has one ("Invalid login credentials"), otherwise the system description.
    var userFacingMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
