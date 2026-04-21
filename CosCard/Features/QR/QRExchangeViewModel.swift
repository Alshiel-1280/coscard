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

    private var env: AppEnvironment?

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
            let pay = LightweightProfilePayload(
                ephemeralToken: token,
                displayName: profile.displayName,
                bioShort: profile.bio,
                primarySNSLabel: profile.primarySNSLabel,
                primarySNSURL: profile.primarySNSURL,
                profileVersion: profile.profileVersion,
                iconThumbnailData: nil
            )
            let data = try MPCMessageEncoder.encodeEnvelope(
                messageType: .lightweightProfile,
                exchangeId: sid,
                payload: pay
            )
            let b64 = data.base64EncodedString()
            payloadSummary = "セッション \(String(sid.uuidString.prefix(8)))…"
            qrImage = QRCodeGenerator.makeImage(from: b64, dimension: 240)
            if qrImage == nil {
                errorMessage = "QR を生成できません（データが長すぎる可能性があります）"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleScannedBase64(_ b64: String) async {
        guard let env else { return }
        errorMessage = nil
        scanSuccessMessage = nil
        let trimmed = b64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: trimmed) else {
            errorMessage = "無効なQRコードです"
            return
        }
        do {
            let envelope = try MPCMessageEncoder.decodeEnvelope(raw)
            guard envelope.messageType == .lightweightProfile else {
                errorMessage = "交換用のプロフィールではありません"
                return
            }
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let p = try dec.decode(LightweightProfilePayload.self, from: envelope.payload)
            let peer = LightweightProfile(
                ephemeralToken: p.ephemeralToken,
                displayName: p.displayName,
                bioShort: p.bioShort,
                primarySNSLabel: p.primarySNSLabel,
                primarySNSURL: p.primarySNSURL,
                profileVersion: p.profileVersion,
                iconThumbnailData: p.iconThumbnailData
            )
            try await env.exchangeSessionRepository.ensureSession(
                id: envelope.exchangeId,
                transport: "qr",
                peerPreviewName: p.displayName,
                peerPreviewIcon: p.iconThumbnailData
            )
            let uc = SaveExchangeResultUseCase(
                peerRepository: env.peerRepository,
                exchangeSessionRepository: env.exchangeSessionRepository,
                tokenRepository: env.tokenRepository
            )
            try await uc.execute(
                sessionId: envelope.exchangeId,
                peerProfile: peer,
                memo: nil,
                eventTag: nil,
                confirmationCode: nil
            )
            scanSuccessMessage = "\(p.displayName) を保存しました"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
