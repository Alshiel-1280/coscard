import Foundation

/// 近傍で見つかった候補（固定ユーザーIDは持たない）
struct PeerCandidate: Identifiable, Equatable, Hashable, Sendable {
    var id: String { mpcPeerId }
    var mpcPeerId: String
    var previewDisplayName: String
    var previewBioSnippet: String?
    var previewIconThumbnailData: Data?

    init(
        mpcPeerId: String,
        previewDisplayName: String,
        previewBioSnippet: String? = nil,
        previewIconThumbnailData: Data? = nil
    ) {
        self.mpcPeerId = mpcPeerId
        self.previewDisplayName = previewDisplayName
        self.previewBioSnippet = previewBioSnippet
        self.previewIconThumbnailData = previewIconThumbnailData
    }
}
