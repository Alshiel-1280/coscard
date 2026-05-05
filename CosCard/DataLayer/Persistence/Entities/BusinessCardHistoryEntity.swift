import Foundation
import SwiftData

@Model
final class BusinessCardHistoryEntity {
    @Attribute(.unique) var id: UUID
    var cosplayCharacterName: String?
    @Attribute(.externalStorage) var businessCardImageData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        cosplayCharacterName: String? = nil,
        businessCardImageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.cosplayCharacterName = cosplayCharacterName
        self.businessCardImageData = businessCardImageData
        self.createdAt = createdAt
    }
}
