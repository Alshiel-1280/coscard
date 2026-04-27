import Foundation

@MainActor
protocol TokenRepositoryProtocol: AnyObject {
    func issueOutgoingToken(sessionId: UUID?) async throws -> String
    func consumeTokenIfValid(_ value: String) async throws -> Bool
    /// 送信済みプロフィールに紐づく発行トークンを消費済みにする
    func consumeOutgoingTokenForSession(_ sessionId: UUID) async throws
    /// 受信した相手トークンを記録（重複検知・監査用）
    func recordIncomingToken(value: String, sessionId: UUID, peerContactId: UUID?) async throws
    /// 既に任意の方向で同一 token が存在すれば true（リプレイ検知）
    func isTokenAlreadySeen(_ value: String) async throws -> Bool
    /// 未登録なら incoming 行を挿入して true。既存なら false。
    func recordIncomingTokenIfNew(value: String, sessionId: UUID, peerContactId: UUID?) async throws -> Bool
    func pruneExpired() async throws
}
