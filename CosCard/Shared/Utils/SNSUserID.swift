import Foundation

enum SNSUserID {
    enum Service {
        case x
        case instagram
        case tiktok
    }

    static func service(label: String?, rawValue: String? = nil) -> Service? {
        let normalizedLabel = (label ?? "").lowercased()
        if normalizedLabel.contains("insta") {
            return .instagram
        }
        if normalizedLabel.contains("tik") {
            return .tiktok
        }
        if normalizedLabel.contains("x") || normalizedLabel.contains("twitter") {
            return .x
        }

        let text = (rawValue ?? "").trimmedCoscard().lowercased()
        if text.contains("instagram.com") {
            return .instagram
        }
        if text.contains("tiktok.com") {
            return .tiktok
        }
        if text.contains("x.com") || text.contains("twitter.com") {
            return .x
        }
        return nil
    }

    static func displayName(for service: Service) -> String {
        switch service {
        case .x: return "X"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        }
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

    static func profileURL(_ value: String?, service: Service?) -> URL? {
        guard let service else {
            guard let text = value?.trimmedCoscard(),
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http"
            else { return nil }
            return url
        }
        guard let id = normalize(value, service: service) else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        switch service {
        case .x:
            components.host = "x.com"
            components.path = "/\(id)"
        case .instagram:
            components.host = "www.instagram.com"
            components.path = "/\(id)/"
        case .tiktok:
            components.host = "www.tiktok.com"
            components.path = "/@\(id)"
        }
        return components.url
    }
}
