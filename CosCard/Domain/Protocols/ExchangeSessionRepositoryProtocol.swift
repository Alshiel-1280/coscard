import Foundation

@MainActor
protocol ExchangeSessionRepositoryProtocol: AnyObject {
    /// `id` は Multipeer の exchangeId と同一。
    func createSession(id: UUID, transport: String, peerPreviewName: String?, peerPreviewIcon: Data?) async throws
    /// 既存があれば何もしない（QR 再スキャンなど）
    func ensureSession(id: UUID, transport: String, peerPreviewName: String?, peerPreviewIcon: Data?) async throws
    func updateSessionState(id: UUID, state: ExchangeState) async throws
    func completeSession(
        id: UUID,
        result: String,
        failureReason: ExchangeFailureReason?,
        confirmationCode: String?,
        eventTag: String?,
        peerContactId: UUID?
    ) async throws
}
