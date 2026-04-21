import Foundation
import SwiftData

@Model
final class LightweightProfileSnapshotEntity {
    @Attribute(.unique) var id: UUID
    var ownerType: String
    var ownerReferenceId: UUID?
    var displayName: String
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    @Attribute(.externalStorage) var iconThumbnailData: Data?
    var profileVersion: Int
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        ownerType: String,
        ownerReferenceId: UUID? = nil,
        displayName: String,
        bio: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        iconThumbnailData: Data? = nil,
        profileVersion: Int = 1,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.ownerType = ownerType
        self.ownerReferenceId = ownerReferenceId
        self.displayName = displayName
        self.bio = bio
        self.primarySNSLabel = primarySNSLabel
        self.primarySNSURL = primarySNSURL
        self.iconThumbnailData = iconThumbnailData
        self.profileVersion = profileVersion
        self.capturedAt = capturedAt
    }
}
