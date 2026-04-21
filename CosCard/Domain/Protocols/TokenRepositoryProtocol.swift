import Foundation

@MainActor
protocol TokenRepositoryProtocol: AnyObject {
    func issueOutgoingToken(sessionId: UUID?) async throws -> String
    func consumeTokenIfValid(_ value: String) async throws -> Bool
    /// 送信済みプロフィールに紐づく発行トークンを消費済みにする
    func consumeOutgoingTokenForSession(_ sessionId: UUID) async throws
    /// 受信した相手トークンを記録（重複検知・監査用）
    func recordIncomingToken(value: String, sessionId: UUID, peerContactId: UUID?) async throws
    func pruneExpired() async throws
}
