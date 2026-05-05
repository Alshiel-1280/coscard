import Foundation

enum ContactLinkNormalizer {
    static func links(from text: String, sourceType: ContactLinkSourceType) -> [ContactLinkDraft] {
        var drafts: [ContactLinkDraft] = []

        for value in detectedLinkValues(in: text) {
            if let draft = normalize(value, sourceType: sourceType) {
                drafts.append(draft)
            }
        }

        for line in text.components(separatedBy: .newlines) {
            guard let hintedPlatform = platformHint(in: line) else { continue }
            for handle in handles(in: line) {
                if let draft = normalize(handle, hintedPlatform: hintedPlatform, sourceType: sourceType) {
                    drafts.append(draft)
                }
            }
            for value in labeledIDs(in: line) {
                if let draft = normalize(value, hintedPlatform: hintedPlatform, sourceType: sourceType) {
                    drafts.append(draft)
                }
            }
        }

        return unique(drafts)
    }

    static func normalize(
        _ value: String,
        hintedPlatform: ContactLinkPlatform? = nil,
        sourceType: ContactLinkSourceType
    ) -> ContactLinkDraft? {
        let original = cleanOriginal(value)
        guard !original.isEmpty else { return nil }

        if let email = normalizedEmail(original) {
            return ContactLinkDraft(
                platform: .email,
                originalValue: original,
                normalizedURL: "mailto:\(email)",
                usernameCandidate: email,
                sourceType: sourceType
            )
        }

        if let phone = normalizedPhone(original), hintedPlatform == nil {
            return ContactLinkDraft(
                platform: .phone,
                originalValue: original,
                normalizedURL: "tel:\(phone)",
                usernameCandidate: phone,
                sourceType: sourceType
            )
        }

        if original.hasPrefix("@"), let hintedPlatform {
            let username = trimUsername(original)
            return ContactLinkDraft(
                platform: hintedPlatform,
                originalValue: original,
                normalizedURL: normalizedSocialURL(username: username, platform: hintedPlatform),
                usernameCandidate: username,
                sourceType: sourceType
            )
        }

        if let hintedPlatform, isPlainHandle(original) {
            let username = trimUsername(original)
            return ContactLinkDraft(
                platform: hintedPlatform,
                originalValue: original,
                normalizedURL: normalizedSocialURL(username: username, platform: hintedPlatform),
                usernameCandidate: username,
                sourceType: sourceType
            )
        }

        guard let url = urlCandidate(from: original) else {
            return nil
        }

        let platform = platform(for: url, hintedPlatform: hintedPlatform)
        let username = usernameCandidate(from: url, platform: platform)
        let normalizedURL = normalizedURL(from: url, platform: platform, username: username)

        return ContactLinkDraft(
            platform: platform,
            originalValue: original,
            normalizedURL: normalizedURL,
            usernameCandidate: username,
            sourceType: sourceType
        )
    }

    static func unique(_ links: [ContactLinkDraft]) -> [ContactLinkDraft] {
        var seen: Set<String> = []
        var result: [ContactLinkDraft] = []
        for link in links {
            let key = [
                link.platform.rawValue,
                (link.normalizedURL ?? "").lowercased(),
                (link.usernameCandidate ?? "").lowercased(),
                link.originalValue.lowercased(),
            ].joined(separator: "|")
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(link)
        }
        return result
    }

    private static func detectedLinkValues(in text: String) -> [String] {
        let nsText = text as NSString
        var values: [String] = []
        if let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
                | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) {
            detector.enumerateMatches(
                in: text,
                options: [],
                range: NSRange(location: 0, length: nsText.length)
            ) { match, _, _ in
                guard let match else { return }
                if let url = match.url {
                    values.append(url.absoluteString)
                } else if let phoneNumber = match.phoneNumber {
                    values.append(phoneNumber)
                } else {
                    values.append(nsText.substring(with: match.range))
                }
            }
        }

        values.append(contentsOf: matches(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: text, options: [.caseInsensitive]))
        values.append(contentsOf: matches(pattern: #"(?i)(?:https?://)?(?:www\.)?(?:x\.com|twitter\.com|instagram\.com|tiktok\.com|lit\.link|linktr\.ee)/[^\s　]+"#, in: text))
        return values
    }

    private static func handles(in text: String) -> [String] {
        matches(pattern: #"@[A-Za-z0-9._]{2,50}"#, in: text)
    }

    private static func labeledIDs(in text: String) -> [String] {
        let pattern = #"(?i)(?:x|twitter|instagram|insta|ig|tiktok|tik tok|インスタ|ティックトック|Ｘ|ｘ)\s*[:：]\s*@?([A-Za-z0-9._]{2,50})"#
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    private static func platformHint(in text: String) -> ContactLinkPlatform? {
        let lower = text.lowercased()
        if lower.contains("instagram") || lower.contains("insta") || lower.contains("インスタ") || lower.contains("ig") {
            return .instagram
        }
        if lower.contains("tiktok") || lower.contains("tik tok") || lower.contains("ティックトック") {
            return .tiktok
        }
        if lower.contains("twitter") || lower.contains("x:") || lower.contains("x：") || lower.contains("Ｘ") {
            return .x
        }
        return nil
    }

    private static func isPlainHandle(_ value: String) -> Bool {
        !value.contains("/")
            && !value.contains("://")
            && !value.contains(" ")
            && !value.contains("　")
            && normalizedEmail(value) == nil
    }

    private static func matches(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map {
            nsText.substring(with: $0.range)
        }
    }

    private static func cleanOriginal(_ value: String) -> String {
        var text = value.trimmedCoscard()
        let trimming = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "、。，．,。()[]{}<>「」『』"))
        text = text.trimmingCharacters(in: trimming)
        while text.hasSuffix(".") || text.hasSuffix("。") || text.hasSuffix(",") {
            text.removeLast()
        }
        return text
    }

    private static func normalizedEmail(_ value: String) -> String? {
        let text = value
            .replacingOccurrences(of: "mailto:", with: "", options: [.caseInsensitive])
            .trimmedCoscard()
            .lowercased()
        guard text.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return text
    }

    private static func normalizedPhone(_ value: String) -> String? {
        let allowed = CharacterSet(charactersIn: "+0123456789")
        let normalized = value.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        let digitCount = normalized.filter(\.isNumber).count
        guard digitCount >= 8 else { return nil }
        return normalized
    }

    private static func urlCandidate(from value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        guard value.contains("."), !value.contains(" ") && !value.contains("　") else {
            return nil
        }
        return URL(string: "https://\(value)")
    }

    private static func platform(for url: URL, hintedPlatform: ContactLinkPlatform?) -> ContactLinkPlatform {
        if let hintedPlatform {
            return hintedPlatform
        }
        let host = (url.host ?? "").lowercased()
        if host.contains("x.com") || host.contains("twitter.com") {
            return .x
        }
        if host.contains("instagram.com") {
            return .instagram
        }
        if host.contains("tiktok.com") {
            return .tiktok
        }
        if host.contains("lit.link") {
            return .litlink
        }
        if host.contains("linktr.ee") {
            return .linktree
        }
        return .website
    }

    private static func usernameCandidate(from url: URL, platform: ContactLinkPlatform) -> String? {
        let pathParts = url.pathComponents.filter { $0 != "/" }
        guard let first = pathParts.first else { return nil }
        switch platform {
        case .x, .instagram, .litlink, .linktree:
            return trimUsername(first)
        case .tiktok:
            return trimUsername(first)
        case .website, .email, .phone, .other:
            return nil
        }
    }

    private static func normalizedURL(
        from url: URL,
        platform: ContactLinkPlatform,
        username: String?
    ) -> String? {
        switch platform {
        case .x:
            return normalizedSocialURL(username: username, platform: platform)
        case .instagram:
            return normalizedSocialURL(username: username, platform: platform)
        case .tiktok:
            return normalizedSocialURL(username: username, platform: platform)
        case .litlink, .linktree, .website, .other:
            return normalizedWebURL(url)
        case .email, .phone:
            return url.absoluteString
        }
    }

    private static func normalizedSocialURL(username: String?, platform: ContactLinkPlatform) -> String? {
        guard let username, !username.isEmpty else { return nil }
        switch platform {
        case .x:
            return SNSUserID.profileURL(username, service: .x)?.absoluteString
        case .instagram:
            return SNSUserID.profileURL(username, service: .instagram)?.absoluteString
        case .tiktok:
            return SNSUserID.profileURL(username, service: .tiktok)?.absoluteString
        case .litlink:
            return "https://lit.link/\(username)"
        case .linktree:
            return "https://linktr.ee/\(username)"
        case .website, .email, .phone, .other:
            return nil
        }
    }

    private static func normalizedWebURL(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.scheme = (components.scheme ?? "https").lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        return components.url?.absoluteString
    }

    private static func trimUsername(_ value: String) -> String {
        var text = value.trimmedCoscard()
        while text.hasPrefix("@") {
            text.removeFirst()
        }
        if let separator = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            text = String(text[..<separator])
        }
        return text.trimmedCoscard()
    }
}
