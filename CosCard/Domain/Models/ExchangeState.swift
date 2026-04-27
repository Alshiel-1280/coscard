import Foundation

enum ExchangeState: String, Codable, Sendable {
    case idle
    case advertising
    case browsing
    case candidateFound
    case invitationSent
    case invitationReceived
    case awaitingLocalApproval
    case awaitingPeerApproval
    case exchanging
    case saving
    case succeeded
    case failed
    case cancelled

    var localizedLabel: String {
        switch self {
        case .idle: return "待機中"
        case .advertising: return "公開中"
        case .browsing: return "探索中…"
        case .candidateFound: return "候補あり"
        case .invitationSent: return "招待を送信中…"
        case .invitationReceived: return "招待を受信"
        case .awaitingLocalApproval: return "確認コードを確認中"
        case .awaitingPeerApproval: return "相手の承認待ち…"
        case .exchanging: return "交換中…"
        case .saving: return "保存中…"
        case .succeeded: return "完了"
        case .failed: return "失敗"
        case .cancelled: return "キャンセル"
        }
    }
}
