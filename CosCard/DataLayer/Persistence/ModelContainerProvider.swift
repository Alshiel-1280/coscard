import Foundation
import SwiftData

enum ModelContainerProvider {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfileEntity.self,
            BusinessCardHistoryEntity.self,
            PeerContactEntity.self,
            ExchangeSessionEntity.self,
            LightweightProfileSnapshotEntity.self,
            ExchangeTokenEntity.self,
            EventTagEntity.self,
        ])
        let config = ModelConfiguration(
            "CosCard",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// SwiftUI プレビュー用
    static func makePreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfileEntity.self,
            BusinessCardHistoryEntity.self,
            PeerContactEntity.self,
            ExchangeSessionEntity.self,
            LightweightProfileSnapshotEntity.self,
            ExchangeTokenEntity.self,
            EventTagEntity.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
