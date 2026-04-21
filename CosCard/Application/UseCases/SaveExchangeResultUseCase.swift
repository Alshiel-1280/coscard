import Foundation

@MainActor
struct SaveExchangeResultUseCase {
    let peerRepository: PeerRepositoryProtocol
    let exchangeSessionRepository: ExchangeSessionRepositoryProtocol
    let tokenRepository: TokenRepositoryProtocol

    func execute(
        sessionId: UUID,
        peerProfile: LightweightProfile,
        memo: String?,
        eventTag: String?,
        confirmationCode: String?
    ) async throws {
        let key = LocalPeerKey.make(from: peerProfile)
        try await ResolveDuplicateExchangeUseCase().logIfDuplicate(localPeerKey: key, peerRepository: peerRepository)
        let peerId = try await peerRepository.upsertPeerFromExchange(
            localPeerKey: key,
            received: peerProfile,
            memo: memo,
            eventTag: eventTag
        )
        try await tokenRepository.recordIncomingToken(
            value: peerProfile.ephemeralToken,
            sessionId: sessionId,
            peerContactId: peerId
        )
        try await exchangeSessionRepository.completeSession(
            id: sessionId,
            result: "success",
            failureReason: nil,
            confirmationCode: confirmationCode,
            eventTag: eventTag,
            peerContactId: peerId
        )
    }
}
