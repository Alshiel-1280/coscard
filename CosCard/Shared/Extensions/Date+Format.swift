import Foundation

extension Date {
    func coscardShortString(locale: Locale = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }
}
