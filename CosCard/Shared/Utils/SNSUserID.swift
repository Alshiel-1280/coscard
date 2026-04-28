import Foundation

enum SNSUserID {
    enum Service {
        case x
        case instagram
        case tiktok
    }

    static func normalize(_ value: String?, service: Service? = nil) -> String? {
        var text = (value ?? "").trimmedCoscard()
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), let host = url.host?.lowercased() {
            let pathParts = url.pathComponents.filter { $0 != "/" }
            switch service {
            case .x where host.contains("x.com") || host.contains("twitter.com"):
                text = pathParts.first ?? text
            case .instagram where host.contains("instagram.com"):
                text = pathParts.first ?? text
            case .tiktok where host.contains("tiktok.com"):
                text = pathParts.first ?? text
            case .none, .some:
                text = pathParts.first ?? text
            }
        } else {
            text = text
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            for prefix in ["x.com/", "twitter.com/", "instagram.com/", "tiktok.com/"] {
                if text.lowercased().hasPrefix(prefix) {
                    text.removeFirst(prefix.count)
                    break
                }
            }
            if let separator = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
                text = String(text[..<separator])
            }
        }

        text = text.trimmedCoscard()
        while text.hasPrefix("@") {
            text.removeFirst()
        }
        return text.isEmpty ? nil : text
    }

    static func display(_ value: String?, service: Service? = nil) -> String? {
        guard let id = normalize(value, service: service) else { return nil }
        return "@\(id)"
    }
}
