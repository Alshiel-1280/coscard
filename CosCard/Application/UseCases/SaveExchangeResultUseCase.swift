import Foundation

enum DuplicateExchangeSaveChoice: Equatable, Sendable {
    case updateExisting
    case skip
}

struct ExchangeSaveResult: Equatable, Sendable {
    let peerContactId: UUID?
    let duplicateCheck: DuplicateExchangeCheck
    let didSavePeer: Bool

    var skippedDuplicate: Bool {
        duplicateCheck.isDuplicate && !didSavePeer
    }
}

@MainActor
struct SaveExchangeResultUseCase {
    let peerRepository: PeerRepositoryProtocol
    let exchangeSessionRepository: ExchangeSessionRepositoryProtocol
    let tokenRepository: TokenRepositoryProtocol

    @discardableResult
    func execute(
        sessionId: UUID,
        peerProfile: LightweightProfile,
        memo: String?,
        eventTag: String?,
        confirmationCode: String?,
        duplicateChoice: DuplicateExchangeSaveChoice = .updateExisting
    ) async throws -> ExchangeSaveResult {
        let duplicateCheck = try await ResolveDuplicateExchangeUseCase().check(
            peerProfile: peerProfile,
            peerRepository: peerRepository
        )
        guard try await tokenRepository.recordIncomingTokenIfNew(
            value: peerProfile.ephemeralToken,
            sessionId: sessionId,
            peerContactId: nil
        ) else {
            throw CosCardError.tokenAlreadyUsed
        }
        if duplicateCheck.isDuplicate && duplicateChoice == .skip {
            try await exchangeSessionRepository.completeSession(
                id: sessionId,
                result: "skipped_duplicate",
                failureReason: nil,
                confirmationCode: confirmationCode,
                eventTag: eventTag,
                peerContactId: nil
            )
            return ExchangeSaveResult(
                peerContactId: nil,
                duplicateCheck: duplicateCheck,
                didSavePeer: false
            )
        }

        let peerId = try await peerRepository.upsertPeerFromExchange(
            localPeerKey: duplicateCheck.localPeerKey,
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
        return ExchangeSaveResult(
            peerContactId: peerId,
            duplicateCheck: duplicateCheck,
            didSavePeer: true
        )
    }
}
