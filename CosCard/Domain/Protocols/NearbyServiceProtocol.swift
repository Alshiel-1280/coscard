import Foundation

/// 近傍通信の抽象。実装は DataLayer/Nearby に閉じる。
@MainActor
protocol NearbyServiceProtocol: AnyObject {
    var exchangeState: ExchangeState { get }
    var candidates: [PeerCandidate] { get }
    var incomingInvitePreviewName: String? { get }
    var activeExchangeId: UUID? { get }
    var isInviteInitiator: Bool { get }
    var pendingInvitationExchangeId: UUID? { get }

    var onSessionConnected: (() -> Void)? { get set }
    /// セッション切断時（交換中のみ MPCManager 側で発火）
    var onPeerDisconnected: (() -> Void)? { get set }
    /// 広告・ブラウズ開始失敗（ローカルネットワーク権限など）
    var onPermissionError: ((String) -> Void)? { get set }
    /// 招待元がブロック一覧と一致する場合に true を返す（同期）
    var inviteAutoRejectPredicate: ((String?, String?) -> Bool)? { get set }

    func startAdvertisingAndBrowsing(displayName: String) async throws
    func stop() async

    func sendInvite(
        to candidate: PeerCandidate,
        previewName: String,
        previewIcon: Data?,
        publicProfileId: String?,
        exchangeId: UUID
    ) async throws
    func acceptInvite() async throws
    func rejectInvite() async throws

    func sendConfirmationCode(_ code: String, exchangeId: UUID) async throws
    func sendApproval(approved: Bool, exchangeId: UUID) async throws
    func sendLightweightProfile(_ profile: LightweightProfile, exchangeId: UUID) async throws
    func cancel(reason: String?) async throws

    var onEnvelopeReceived: ((WireEnvelope) -> Void)? { get set }
}
