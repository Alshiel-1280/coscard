import Foundation
import Security

enum ConfirmationCodeGenerator {
    static func generateFourDigits() -> String {
        var bytes = [UInt8](repeating: 0, count: 2)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 2, $0.baseAddress!) }
        let value = (UInt16(bytes[0]) << 8 | UInt16(bytes[1])) % 10000
        return String(format: "%04d", value)
    }
}
