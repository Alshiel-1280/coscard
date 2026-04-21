import Foundation

extension String {
    func trimmedCoscard() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizedForPeerKey() -> String {
        trimmedCoscard().lowercased()
    }

    func normalizedSNSURLForPeerKey() -> String {
        trimmedCoscard().lowercased()
    }
}

enum ProfileValidation {
    static let displayNameRange = 1 ... 24
    static let displayNameReadingRange = 0 ... 24
    static let bioRange = 0 ... 80
    static let snsLabelRange = 0 ... 20
    static let snsURLRange = 0 ... 200

    static func validateDisplayName(_ s: String) -> Bool {
        let t = s.trimmedCoscard()
        return displayNameRange.contains(t.count)
    }

    static func validateDisplayNameReading(_ s: String?) -> Bool {
        let t = (s ?? "").trimmedCoscard()
        return displayNameReadingRange.contains(t.count)
    }

    static func validateBio(_ s: String?) -> Bool {
        let t = (s ?? "").trimmedCoscard()
        return bioRange.contains(t.count)
    }

    static func validateSNSLabel(_ s: String?) -> Bool {
        let t = (s ?? "").trimmedCoscard()
        return snsLabelRange.contains(t.count)
    }

    static func validateSNSURL(_ s: String?) -> Bool {
        let t = (s ?? "").trimmedCoscard()
        return snsURLRange.contains(t.count)
    }
}
