import Foundation

enum BusinessCardCaptureSourceType: String, CaseIterable, Codable, Sendable {
    case camera
    case library

    var displayName: String {
        switch self {
        case .camera: return "カメラ"
        case .library: return "写真"
        }
    }
}

enum ContactLinkPlatform: String, CaseIterable, Codable, Identifiable, Sendable {
    case x
    case instagram
    case tiktok
    case litlink
    case linktree
    case website
    case email
    case phone
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .x: return "X"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .litlink: return "lit.link"
        case .linktree: return "Linktree"
        case .website: return "Web"
        case .email: return "メール"
        case .phone: return "電話"
        case .other: return "その他"
        }
    }
}

enum ContactLinkSourceType: String, CaseIterable, Codable, Sendable {
    case qr
    case ocr
    case manual
    case appExchange

    var displayName: String {
        switch self {
        case .qr: return "QR"
        case .ocr: return "OCR"
        case .manual: return "手入力"
        case .appExchange: return "アプリ交換"
        }
    }
}

struct ContactLinkDraft: Identifiable, Equatable, Sendable {
    var id: UUID
    var platform: ContactLinkPlatform
    var originalValue: String
    var normalizedURL: String?
    var usernameCandidate: String?
    var sourceType: ContactLinkSourceType

    init(
        id: UUID = UUID(),
        platform: ContactLinkPlatform,
        originalValue: String,
        normalizedURL: String? = nil,
        usernameCandidate: String? = nil,
        sourceType: ContactLinkSourceType
    ) {
        self.id = id
        self.platform = platform
        self.originalValue = originalValue
        self.normalizedURL = normalizedURL
        self.usernameCandidate = usernameCandidate
        self.sourceType = sourceType
    }
}

struct ContactLinkSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var peerContactId: UUID?
    var captureId: UUID?
    var platform: ContactLinkPlatform
    var originalValue: String
    var normalizedURL: String?
    var usernameCandidate: String?
    var sourceType: ContactLinkSourceType
    var createdAt: Date
}

struct ExtractionResultDraft: Identifiable, Equatable, Sendable {
    var id: UUID
    var kind: String
    var originalValue: String
    var normalizedValue: String?
    var confidence: Double
    var sourceType: ContactLinkSourceType
    var isAccepted: Bool

    init(
        id: UUID = UUID(),
        kind: String,
        originalValue: String,
        normalizedValue: String? = nil,
        confidence: Double = 0,
        sourceType: ContactLinkSourceType,
        isAccepted: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.originalValue = originalValue
        self.normalizedValue = normalizedValue
        self.confidence = confidence
        self.sourceType = sourceType
        self.isAccepted = isAccepted
    }
}

struct BusinessCardExtraction: Equatable, Sendable {
    var ocrRawText: String?
    var qrRawValues: [String]
    var links: [ContactLinkDraft]
    var extractionResults: [ExtractionResultDraft]
    var suggestedDisplayName: String?
    var suggestedCosplayCharacterName: String?
}

struct BusinessCardImportDraft: Equatable, Sendable {
    var displayName: String
    var cosplayCharacterName: String?
    var memo: String?
    var eventTag: String?
    var imageData: Data
    var thumbnailData: Data?
    var captureSourceType: BusinessCardCaptureSourceType
    var capturedAt: Date
    var ocrRawText: String?
    var qrRawValue: String?
    var links: [ContactLinkDraft]
    var extractionResults: [ExtractionResultDraft]
}

struct BusinessCardMergeCandidate: Identifiable, Equatable, Sendable {
    var id: UUID { peerId }
    var peerId: UUID
    var displayName: String
    var memo: String?
    var reasons: [String]
}
