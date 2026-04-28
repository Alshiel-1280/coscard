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
    static let snsUserIDRange = 0 ... 50

    static func validateDisplayName(_ s: String) -> Bool {
        let t = s.trimmedCoscard()
        return displayNameRange.contains(t.count)
    }

    static func validateSNSUserID(_ s: String?) -> Bool {
        let t = (s ?? "").trimmedCoscard()
        let disallowed: Set<Character> = ["/", ":", "?", "#"]
        return snsUserIDRange.contains(t.count)
            && !t.contains(where: { $0.isWhitespace || disallowed.contains($0) })
    }

    // MARK: - 交換ペイロード（MPC / QR 共通）

    @MainActor
    static func validateIncomingExchange(
        envelope: WireEnvelope,
        ephemeralToken: String,
        tokenRepository: TokenRepositoryProtocol
    ) async throws {
        if let exp = envelope.expiresAt, exp < Date() {
            throw CosCardError.envelopeExpired
        }
        if try await tokenRepository.isTokenAlreadySeen(ephemeralToken) {
            throw CosCardError.tokenAlreadyUsed
        }
    }
}
