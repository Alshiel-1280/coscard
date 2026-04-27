import Foundation

/// 安定した publicProfileId を優先。無い旧ペイロードは表示名・SNS・アイコン hash ベース（ephemeral は含めない）。
enum LocalPeerKey {
    static func make(from profile: LightweightProfile) -> String {
        let iconHash = Checksum.sha256Hex(of: profile.iconThumbnailData ?? Data())
        if let pid = profile.publicProfileId?.trimmedCoscard(), !pid.isEmpty {
            let parts = [
                "pid",
                pid,
                "\(profile.profileVersion)",
            ]
            let h = Checksum.sha256Hex(of: parts.joined(separator: "|"))
            return String(h.prefix(40))
        }
        let parts = [
            "legacy",
            "\(profile.profileVersion)",
            profile.displayName.normalizedForPeerKey(),
            (profile.primarySNSURL ?? "").normalizedSNSURLForPeerKey(),
            iconHash,
        ]
        let h = Checksum.sha256Hex(of: parts.joined(separator: "|"))
        return String(h.prefix(40))
    }
}
