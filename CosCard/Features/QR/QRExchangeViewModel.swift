import Foundation
import SwiftUI
import UIKit

@MainActor
final class QRExchangeViewModel: ObservableObject {
    @Published var qrImage: UIImage?
    @Published var payloadSummary = ""
    @Published var errorMessage: String?
    @Published var scanSuccessMessage: String?
    @Published var showScanner = false
    @Published var showScanComplete = false
    @Published var pendingScanPeerName = ""
    @Published var pendingScanCosplayCharacterName: String?
    @Published var pendingScanIconData: Data?
    @Published var pendingScanBusinessCardImageData: Data?
    @Published var pendingScanIsDuplicate = false

    private var env: AppEnvironment?
    private var scannedProfile: LightweightProfile?
    private var scannedSessionId: UUID?
    private var scannedExchangeIds: Set<UUID> = []

    private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func prepareMyQR() async {
        guard let env else { return }
        errorMessage = nil
        let sid = UUID()
        do {
            try await env.exchangeSessionRepository.ensureSession(
                id: sid,
                transport: "qr",
                peerPreviewName: nil,
                peerPreviewIcon: nil
            )
            let profile = try await env.profileRepository.fetchCurrentProfile()
            guard let profile else {
                errorMessage = "プロフィールがありません"
                return
            }
            let token = try await GenerateEphemeralTokenUseCase(tokenRepository: env.tokenRepository)
                .execute(sessionId: sid)
            let publicId = try await env.profileRepository.ensurePublicProfileId()
            let pay = LightweightProfilePayload(
                ephemeralToken: token,
                publicProfileId: publicId,
                displayName: profile.displayName,
                cosplayCharacterName: profile.cosplayCharacterName,
                bioShort: nil,
                primarySNSLabel: profile.primarySNSLabel,
                primarySNSURL: profile.primarySNSURL,
                twitterURL: profile.twitterURL,
                instagramURL: profile.instagramURL,
                tiktokURL: profile.tiktokURL,
                profileVersion: profile.profileVersion,
                iconThumbnailData: nil,
                // QR はBase64化したEnvelope全体を載せるため、画像系データは容量を抑える目的で送らない。
                businessCardImageData: nil
            )
            let expiresAt = Date().addingTimeInterval(180)
            let data = try MPCMessageEncoder.encodeEnvelope(
                messageType: .lightweightProfile,
                exchangeId: sid,
                payload: pay,
                expiresAt: expiresAt
            )
            let b64 = data.base64EncodedString()
            payloadSummary = "セッション \(String(sid.uuidString.prefix(8)))…"
            qrImage = QRCodeGenerator.makeImage(from: b64, dimension: 240)
            if qrImage == nil {
                errorMessage =
                    "QR を生成できません。プロフィールやSNSの文字数を減らしてから再試行してください。"
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func handleScannedBase64(_ b64: String) async {
        guard let env else { return }
        errorMessage = nil
        scanSuccessMessage = nil
        pendingScanIsDuplicate = false
        pendingScanCosplayCharacterName = nil
        pendingScanIconData = nil
        pendingScanBusinessCardImageData = nil
        let trimmed = b64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: trimmed) else {
            errorMessage = "読み取ったコードが CosCard の交換用データではありません"
            return
        }
        do {
            let envelope = try MPCMessageEncoder.decodeEnvelope(raw)
            guard envelope.messageType == .lightweightProfile else {
                errorMessage = "交換用のプロフィールではありません"
                return
            }
            if scannedExchangeIds.contains(envelope.exchangeId) {
                errorMessage = "この QR は直前に読み取り済みです。別のコードをスキャンしてください。"
                return
            }
            let p = try jsonDecoder.decode(LightweightProfilePayload.self, from: envelope.payload)
            try await ProfileValidation.validateIncomingExchange(
                envelope: envelope,
                ephemeralToken: p.ephemeralToken,
                tokenRepository: env.tokenRepository
            )
            let peer = LightweightProfile(
                ephemeralToken: p.ephemeralToken,
                publicProfileId: p.publicProfileId,
                displayName: p.displayName,
                cosplayCharacterName: p.cosplayCharacterName,
                bioShort: p.bioShort,
                primarySNSLabel: p.primarySNSLabel,
                primarySNSURL: p.primarySNSURL,
                twitterURL: p.twitterURL,
                instagramURL: p.instagramURL,
                tiktokURL: p.tiktokURL,
                profileVersion: p.profileVersion,
                iconThumbnailData: p.iconThumbnailData,
                businessCardImageData: p.businessCardImageData
            )
            if try await isBlocked(peer) {
                errorMessage = "ブロック中の相手です。履歴のブロックリストから解除してから保存してください。"
                return
            }
            try await env.exchangeSessionRepository.ensureSession(
                id: envelope.exchangeId,
                transport: "qr",
                peerPreviewName: p.displayName,
                peerPreviewIcon: p.iconThumbnailData
            )
            let duplicateCheck = try await ResolveDuplicateExchangeUseCase().check(
                peerProfile: peer,
                peerRepository: env.peerRepository
            )
            scannedProfile = peer
            scannedSessionId = envelope.exchangeId
            scannedExchangeIds.insert(envelope.exchangeId)
            pendingScanPeerName = p.displayName
            pendingScanCosplayCharacterName = p.cosplayCharacterName
            pendingScanIconData = p.iconThumbnailData
            pendingScanBusinessCardImageData = p.businessCardImageData
            pendingScanIsDuplicate = duplicateCheck.isDuplicate
            showScanComplete = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func finalizeScan(
        memo: String?,
        eventTag: String?,
        duplicateChoice: DuplicateExchangeSaveChoice = .updateExisting
    ) async {
        guard let env, let profile = scannedProfile, let sid = scannedSessionId else { return }
        errorMessage = nil
        let uc = SaveExchangeResultUseCase(
            peerRepository: env.peerRepository,
            exchangeSessionRepository: env.exchangeSessionRepository,
            tokenRepository: env.tokenRepository
        )
        do {
            let result = try await uc.execute(
                sessionId: sid,
                peerProfile: profile,
                memo: memo,
                eventTag: eventTag,
                confirmationCode: nil,
                duplicateChoice: duplicateChoice
            )
            scanSuccessMessage = result.skippedDuplicate
                ? "\(profile.displayName) の保存をスキップしました"
                : "\(profile.displayName) を保存しました"
            showScanComplete = false
            scannedProfile = nil
            scannedSessionId = nil
            pendingScanIsDuplicate = false
            pendingScanCosplayCharacterName = nil
            pendingScanIconData = nil
            pendingScanBusinessCardImageData = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showScanComplete = false
            scannedProfile = nil
            scannedSessionId = nil
            pendingScanIsDuplicate = false
            pendingScanCosplayCharacterName = nil
            pendingScanIconData = nil
            pendingScanBusinessCardImageData = nil
        }
    }

    func discardPendingScan() {
        showScanComplete = false
        scannedProfile = nil
        scannedSessionId = nil
        pendingScanIsDuplicate = false
        pendingScanCosplayCharacterName = nil
        pendingScanIconData = nil
        pendingScanBusinessCardImageData = nil
    }

    private func isBlocked(_ peer: LightweightProfile) async throws -> Bool {
        guard let env else { return false }
        let localPeerKey = LocalPeerKey.make(from: peer)
        if try await env.peerRepository.isBlockedLocalPeerKey(localPeerKey) {
            return true
        }
        let publicProfileId = peer.publicProfileId?.trimmedCoscard().lowercased() ?? ""
        if !publicProfileId.isEmpty {
            let blockedPublicProfileIds = try await env.peerRepository.blockedPublicProfileIds()
            if blockedPublicProfileIds.contains(publicProfileId) {
                return true
            }
        }
        let normalizedName = peer.displayName.normalizedForPeerKey()
        guard !normalizedName.isEmpty else { return false }
        let blockedNames = try await env.peerRepository.blockedNormalizedDisplayNames()
        return blockedNames.contains(normalizedName)
    }
}
