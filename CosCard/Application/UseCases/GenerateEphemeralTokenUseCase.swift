import Foundation

@MainActor
struct GenerateEphemeralTokenUseCase {
    let tokenRepository: TokenRepositoryProtocol

    func execute(sessionId: UUID?) async throws -> String {
        try await tokenRepository.issueOutgoingToken(sessionId: sessionId)
    }
}
