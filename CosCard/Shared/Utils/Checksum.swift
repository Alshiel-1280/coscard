import CryptoKit
import Foundation

enum Checksum {
    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(of string: String) -> String {
        sha256Hex(of: Data(string.utf8))
    }
}
