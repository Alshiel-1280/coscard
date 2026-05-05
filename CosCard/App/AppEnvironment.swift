import Foundation
import SwiftData

@MainActor
final class AppEnvironment: ObservableObject {
    let modelContext: ModelContext
    let profileRepository: ProfileRepositoryProtocol
    let peerRepository: PeerRepositoryProtocol
    let businessCardRepository: BusinessCardRepositoryProtocol
    let exchangeSessionRepository: ExchangeSessionRepositoryProtocol
    let tokenRepository: TokenRepositoryProtocol
    let nearby: NearbyServiceProtocol

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        profileRepository = ProfileRepository(modelContext: modelContext)
        peerRepository = PeerRepository(modelContext: modelContext)
        businessCardRepository = BusinessCardRepository(modelContext: modelContext)
        exchangeSessionRepository = ExchangeSessionRepository(modelContext: modelContext)
        tokenRepository = TokenRepository(modelContext: modelContext)
        nearby = MPCManager()
    }
}

extension AppEnvironment {
    /// プレビュー・テスト用
    static var preview: AppEnvironment {
        let container = try! ModelContainerProvider.makePreviewContainer()
        let ctx = ModelContext(container)
        return AppEnvironment(modelContext: ctx)
    }
}
