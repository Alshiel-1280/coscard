import Foundation

enum ExchangeFailureReason: String, Codable, Sendable {
    case timeout
    case peerRejected
    case disconnected
    case invalidPayload
    case duplicateExchange
    case saveFailed
    case permissionDenied
    case sessionError
    case cancelledByUser
}
