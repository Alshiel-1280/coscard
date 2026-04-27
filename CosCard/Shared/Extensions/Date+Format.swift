import Foundation

extension Date {
    private static let coscardShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    func coscardShortString() -> String {
        Self.coscardShortFormatter.string(from: self)
    }
}
