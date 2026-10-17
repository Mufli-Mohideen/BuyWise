import Foundation
import CryptoKit
import Security

/// Sign in with Apple replay protection: Apple receives the SHA-256 hash, Supabase verifies the raw nonce.
enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, length, &bytes) != errSecSuccess {
            return UUID().uuidString + UUID().uuidString
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension Error {
    /// The backend's own message when it has one ("Invalid login credentials"), otherwise the system description.
    var userFacingMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
