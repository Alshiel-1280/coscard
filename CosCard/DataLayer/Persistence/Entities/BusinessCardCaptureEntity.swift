import Foundation
import SwiftData

@Model
final class BusinessCardCaptureEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var capturedAt: Date
    var sourceType: String
    var ocrRawText: String?
    var qrRawValue: String?
    var linkedPeerContactId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data? = nil,
        capturedAt: Date = .now,
        sourceType: String,
        ocrRawText: String? = nil,
        qrRawValue: String? = nil,
        linkedPeerContactId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.capturedAt = capturedAt
        self.sourceType = sourceType
        self.ocrRawText = ocrRawText
        self.qrRawValue = qrRawValue
        self.linkedPeerContactId = linkedPeerContactId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
