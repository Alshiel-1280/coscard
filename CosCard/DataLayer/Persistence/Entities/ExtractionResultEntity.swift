import Foundation
import SwiftData

@Model
final class ExtractionResultEntity {
    @Attribute(.unique) var id: UUID
    var captureId: UUID
    var kind: String
    var originalValue: String
    var normalizedValue: String?
    var confidence: Double
    var sourceType: String
    var isAccepted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        captureId: UUID,
        kind: String,
        originalValue: String,
        normalizedValue: String? = nil,
        confidence: Double = 0,
        sourceType: String,
        isAccepted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.captureId = captureId
        self.kind = kind
        self.originalValue = originalValue
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.sourceType = sourceType
        self.isAccepted = isAccepted
        self.createdAt = createdAt
    }
}
