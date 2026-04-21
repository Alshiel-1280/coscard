import Foundation

/// ephemeral token / profileVersion / 正規化名 / SNS URL / アイコン hash を SHA-256 し、先頭 40 文字を localPeerKey にする。
enum LocalPeerKey {
    static func make(from profile: LightweightProfile) -> String {
        let iconHash = Checksum.sha256Hex(of: profile.iconThumbnailData ?? Data())
        let parts = [
            profile.ephemeralToken,
            "\(profile.profileVersion)",
            profile.displayName.normalizedForPeerKey(),
            (profile.primarySNSURL ?? "").normalizedSNSURLForPeerKey(),
            iconHash,
        ]
        let h = Checksum.sha256Hex(of: parts.joined(separator: "|"))
        return String(h.prefix(40))
    }
}
