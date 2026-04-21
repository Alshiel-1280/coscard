import Foundation

enum ConfirmationCodeGenerator {
    static func generateFourDigits() -> String {
        String(format: "%04d", Int.random(in: 0 ... 9999))
    }
}
