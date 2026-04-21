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
}
