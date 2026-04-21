import Foundation
import SwiftData

@Model
final class EventTagEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date?
    var note: String?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.note = note
    }
}
