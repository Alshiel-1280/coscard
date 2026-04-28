import Foundation
import UIKit

/// 交換フロー: 接続後に発信側が4桁送信 → 双方承認 → プロフィール送受信 → 完了画面で保存。
@MainActor
final class ExchangeViewModel: ObservableObject {
    @Published private(set) var candidates: [PeerCandidate] = []
    @Published private(set) var exchangeState: ExchangeState = .idle
    @Published var selected: PeerCandidate?
    @Published var incomingPreviewName: String?
    @Published var errorMessage: String?
    @Published var showIncomingInviteSheet = false

    @Published var sessionEntityId: UUID?
    @Published var confirmationCode: String?
    @Published private(set) var localUserApproved = false
    @Published private(set) var peerHasApproved = false
    @Published private(set) var receivedPeerProfile: LightweightProfile?
    @Published private(set) var receivedPeerIsDuplicate = false
    @Published var showExchangeComplete = false
    /// 自分のプロフィール送信が完了したか（UI 用）
    @Published private(set) var hasSentMyProfile = false

    private var env: AppEnvironment?
    private var pollTask: Task<Void, Never>?
    private var exchangeTimeoutTask: Task<Void, Never>?
    private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func attach(_ environment: AppEnvironment) {
        env = environment
        environment.nearby.onEnvelopeReceived = { [weak self] envelope in
            Task { @MainActor in
                self?.handleEnvelope(envelope)
                self?.syncFromNearby()
            }
        }
        environment.nearby.onSessionConnected = { [weak self] in
            Task { @MainActor in
                self?.onMPCSessionConnected()
                self?.syncFromNearby()
            }
        }
        environment.nearby.onPeerDisconnected = { [weak self] in
            Task { @MainActor in
                self?.handlePeerDisconnected()
            }
        }
        environment.nearby.onPermissionError = { [weak self] msg in
            Task { @MainActor in
                self?.errorMessage = msg
                self?.syncFromNearby()
            }
        }
        Task { await refreshInviteBlockList(environment) }
    }

    /// ブロック一覧変更後に招待拒否プリケートを更新する。
    func refreshInviteBlockListAsync() async {
        guard let env else { return }
        await refreshInviteBlockList(env)
    }

    private func refreshInviteBlockList(_ environment: AppEnvironment) async {
        var blockedNames: Set<String>
        var blockedPublicProfileIds: Set<String>
        do {
            blockedNames = try await environment.peerRepository.blockedNormalizedDisplayNames()
            blockedPublicProfileIds = try await environment.peerRepository.blockedPublicProfileIds()
        } catch {
            AppLogger.error("blocked invite identifiers failed: \(error.localizedDescription)", category: "Exchange")
            blockedNames = []
            blockedPublicProfileIds = []
        }
        environment.nearby.inviteAutoRejectPredicate = { preview, publicProfileId in
            if let pid = Self.normalizedPublicProfileId(publicProfileId), blockedPublicProfileIds.contains(pid) {
                return true
            }
            guard let p = preview?.trimmedCoscard(), !p.isEmpty else { return false }
            return blockedNames.contains(p.normalizedForPeerKey())
        }
    }

    func cancelPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func ensureExchangeModeEnabled() async {
        guard let env else { return }
        if env.nearby.exchangeState == .idle {
            await startExchange()
            return
        }
        if pollTask == nil {
            startPolling()
        }
        syncFromNearby()
    }

    func startExchange() async {
        guard let env else { return }
        errorMessage = nil
        resetExchangeFlow()
        let profile: ProfileSummary?
        do {
            profile = try await env.profileRepository.fetchCurrentProfile()
        } catch {
            AppLogger.log("fetchCurrentProfile failed in startExchange: \(error.localizedDescription)", category: "Exchange")
            profile = nil
        }
        let name = profile?.displayName ?? "Guest"
        let uc = StartExchangeUseCase(nearby: env.nearby)
        do {
            try await uc.execute(displayName: name)
            await refreshInviteBlockList(env)
            startPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopExchange() async {
        pollTask?.cancel()
        pollTask = nil
        guard let env else { return }
        if let sid = sessionEntityId {
            do {
                try await env.nearby.cancel(reason: "user_stop")
            } catch {
                AppLogger.log("cancel failed in stopExchange: \(error.localizedDescription)", category: "Exchange")
            }
            do {
                try await env.exchangeSessionRepository.failSession(
                    id: sid,
                    state: .cancelled,
                    failureReason: .cancelledByUser
                )
            } catch {
                AppLogger.log("failSession failed in stopExchange: \(error.localizedDescription)", category: "Exchange")
            }
        }
        resetExchangeFlow()
        await StopExchangeUseCase(nearby: env.nearby).execute()
        syncFromNearby()
    }

    /// 交換途中のキャンセル（探索は継続）。
    func cancelActiveExchange() async {
        guard let env, let sid = sessionEntityId else { return }
        errorMessage = nil
        do {
            try await env.nearby.cancel(reason: "user")
        } catch {
            AppLogger.log("cancel failed in cancelActiveExchange: \(error.localizedDescription)", category: "Exchange")
        }
        do {
            try await env.exchangeSessionRepository.failSession(
                id: sid,
                state: .cancelled,
                failureReason: .cancelledByUser
            )
        } catch {
            AppLogger.log("failSession failed in cancelActiveExchange: \(error.localizedDescription)", category: "Exchange")
        }
        resetExchangeFlow()
        syncFromNearby()
    }

    func retryExchange() async {
        errorMessage = nil
        await startExchange()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { self?.syncFromNearby() }
            }
        }
    }

    func syncFromNearby() {
        guard let env else { return }
        candidates = env.nearby.candidates
        let prevState = exchangeState
        exchangeState = env.nearby.exchangeState
        incomingPreviewName = env.nearby.incomingInvitePreviewName
        if env.nearby.exchangeState == .invitationReceived, env.nearby.incomingInvitePreviewName != nil, !showExchangeComplete {
            if prevState != .invitationReceived {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            showIncomingInviteSheet = true
        }
    }

    func sendInvite(to candidate: PeerCandidate) async {
        guard let env else { return }
        errorMessage = nil
        let exchangeId = UUID()
        sessionEntityId = exchangeId
        let profile: ProfileSummary?
        do {
            profile = try await env.profileRepository.fetchCurrentProfile()
        } catch {
            AppLogger.log("fetchCurrentProfile failed in sendInvite: \(error.localizedDescription)", category: "Exchange")
            profile = nil
        }
        let publicProfileId = await publicProfileIdForInvite(profile: profile, environment: env)
        do {
            try await env.exchangeSessionRepository.createSession(
                id: exchangeId,
                transport: "mpc",
                peerPreviewName: candidate.previewDisplayName,
                peerPreviewIcon: candidate.previewIconThumbnailData
            )
            try await SendInviteUseCase(nearby: env.nearby).execute(
                candidate: candidate,
                previewName: profile?.displayName ?? "?",
                previewIcon: profile?.iconThumbnailData,
                publicProfileId: publicProfileId,
                exchangeId: exchangeId
            )
            try await env.exchangeSessionRepository.updateSessionState(id: exchangeId, state: .invitationSent)
            scheduleExchangeTimeout()
            syncFromNearby()
        } catch {
            errorMessage = error.localizedDescription
            sessionEntityId = nil
        }
    }

    func acceptInvite() async {
        showIncomingInviteSheet = false
        guard let env else { return }
        errorMessage = nil
        guard let pendingId = env.nearby.pendingInvitationExchangeId ?? env.nearby.activeExchangeId else {
            errorMessage = "招待情報がありません"
            return
        }
        sessionEntityId = pendingId
        do {
            try await env.exchangeSessionRepository.createSession(
                id: pendingId,
                transport: "mpc",
                peerPreviewName: env.nearby.incomingInvitePreviewName,
                peerPreviewIcon: nil
            )
            try await AcceptInviteUseCase(nearby: env.nearby).execute()
            scheduleExchangeTimeout()
            syncFromNearby()
        } catch {
            errorMessage = error.localizedDescription
            sessionEntityId = nil
        }
    }

    func rejectInvite() async {
        showIncomingInviteSheet = false
        guard let env else { return }
        do {
            try await RejectInviteUseCase(nearby: env.nearby).execute()
            resetExchangeFlow()
            syncFromNearby()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 4桁を確認したうえで承認を送る。
    func userConfirmAndApprove() async {
        guard let env, let id = sessionEntityId else { return }
        localUserApproved = true
        do {
            try await env.nearby.sendApproval(approved: true, exchangeId: id)
            tryProceedToSendProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finalizeExchange(
        memo: String?,
        eventTag: String?,
        duplicateChoice: DuplicateExchangeSaveChoice = .updateExisting
    ) async {
        guard let env, let profile = receivedPeerProfile, let sid = sessionEntityId else { return }
        let uc = SaveExchangeResultUseCase(
            peerRepository: env.peerRepository,
            exchangeSessionRepository: env.exchangeSessionRepository,
            tokenRepository: env.tokenRepository
        )
        do {
            try await uc.execute(
                sessionId: sid,
                peerProfile: profile,
                memo: memo,
                eventTag: eventTag,
                confirmationCode: confirmationCode,
                duplicateChoice: duplicateChoice
            )
            showExchangeComplete = false
            resetExchangeFlow()
            syncFromNearby()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func onMPCSessionConnected() {
        guard let env, let id = sessionEntityId else { return }
        if env.nearby.isInviteInitiator {
            let code = ConfirmationCodeGenerator.generateFourDigits()
            confirmationCode = code
            Task {
                do {
                    try await env.exchangeSessionRepository.updateSessionState(id: id, state: .awaitingLocalApproval)
                    try await env.nearby.sendConfirmationCode(code, exchangeId: id)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        }
    }

    private func handlePeerDisconnected() {
        exchangeTimeoutTask?.cancel()
        exchangeTimeoutTask = nil
        guard let sid = sessionEntityId else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        Task {
            do {
                try await env?.exchangeSessionRepository.failSession(
                    id: sid,
                    state: .failed,
                    failureReason: .disconnected
                )
            } catch {
                AppLogger.error("failSession failed in handlePeerDisconnected: \(error.localizedDescription)", category: "Exchange")
            }
            await MainActor.run {
                self.errorMessage = "接続が切断されました"
                self.resetExchangeFlow()
                self.syncFromNearby()
            }
        }
    }

    private func scheduleExchangeTimeout() {
        exchangeTimeoutTask?.cancel()
        exchangeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            await MainActor.run {
                guard let self else { return }
                guard let sid = self.sessionEntityId else { return }
                guard !self.showExchangeComplete else { return }
                self.errorMessage = "交換がタイムアウトしました"
                Task {
                    do {
                        try await self.env?.nearby.cancel(reason: "timeout")
                    } catch {
                        AppLogger.error("cancel failed in timeout: \(error.localizedDescription)", category: "Exchange")
                    }
                    do {
                        try await self.env?.exchangeSessionRepository.failSession(
                            id: sid,
                            state: .failed,
                            failureReason: .timeout
                        )
                    } catch {
                        AppLogger.error("failSession failed in timeout: \(error.localizedDescription)", category: "Exchange")
                    }
                    await MainActor.run {
                        self.resetExchangeFlow()
                        self.syncFromNearby()
                    }
                }
            }
        }
    }

    private func handleEnvelope(_ envelope: WireEnvelope) {
        guard let sid = sessionEntityId, envelope.exchangeId == sid else { return }
        if let exp = envelope.expiresAt, exp < Date() {
            errorMessage = "メッセージの有効期限が切れています"
            return
        }
        do {
            switch envelope.messageType {
            case .confirmationCode:
                let p = try jsonDecoder.decode(ConfirmationCodePayload.self, from: envelope.payload)
                if confirmationCode == nil {
                    confirmationCode = p.code
                }
                Task {
                    try? await env?.exchangeSessionRepository.updateSessionState(id: sid, state: .awaitingLocalApproval)
                }
            case .approvalState:
                let p = try jsonDecoder.decode(ApprovalStatePayload.self, from: envelope.payload)
                if p.approved {
                    peerHasApproved = true
                    tryProceedToSendProfiles()
                } else {
                    errorMessage = "相手が承認しませんでした"
                }
            case .lightweightProfile:
                let p = try jsonDecoder.decode(LightweightProfilePayload.self, from: envelope.payload)
                guard let env else { break }
                Task { @MainActor in
                    do {
                        try await ProfileValidation.validateIncomingExchange(
                            envelope: envelope,
                            ephemeralToken: p.ephemeralToken,
                            tokenRepository: env.tokenRepository
                        )
                        let peerProfile = LightweightProfile(
                            ephemeralToken: p.ephemeralToken,
                            publicProfileId: p.publicProfileId,
                            displayName: p.displayName,
                            bioShort: p.bioShort,
                            primarySNSLabel: p.primarySNSLabel,
                            primarySNSURL: p.primarySNSURL,
                            profileVersion: p.profileVersion,
                            iconThumbnailData: p.iconThumbnailData
                        )
                        let duplicateCheck = try await ResolveDuplicateExchangeUseCase().check(
                            peerProfile: peerProfile,
                            peerRepository: env.peerRepository
                        )
                        self.receivedPeerProfile = peerProfile
                        self.receivedPeerIsDuplicate = duplicateCheck.isDuplicate
                        self.checkReadyForComplete()
                    } catch {
                        self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            case .cancel:
                let failSid = sid
                errorMessage = "相手がキャンセルしました"
                Task { @MainActor in
                    do {
                        try await self.env?.exchangeSessionRepository.failSession(
                            id: failSid,
                            state: .cancelled,
                            failureReason: .peerRejected
                        )
                    } catch {
                        AppLogger.error("failSession failed on peer cancel: \(error.localizedDescription)", category: "Exchange")
                    }
                    self.resetExchangeFlow()
                    self.syncFromNearby()
                }
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func tryProceedToSendProfiles() {
        guard let env, let id = sessionEntityId else { return }
        guard localUserApproved, peerHasApproved else { return }
        guard !hasSentMyProfile else { return }
        Task {
            await sendMyProfile(env: env, exchangeId: id)
        }
    }

    private func sendMyProfile(env: AppEnvironment, exchangeId: UUID) async {
        guard !hasSentMyProfile else { return }
        hasSentMyProfile = true
        do {
            try await env.exchangeSessionRepository.updateSessionState(id: exchangeId, state: .exchanging)
            let profile = try await env.profileRepository.fetchCurrentProfile()
            guard let profile else {
                hasSentMyProfile = false
                errorMessage = "プロフィールがありません"
                return
            }
            let token = try await GenerateEphemeralTokenUseCase(tokenRepository: env.tokenRepository)
                .execute(sessionId: exchangeId)
            let publicId = try await env.profileRepository.ensurePublicProfileId()
            let thumb = profile.iconThumbnailData
            let light = LightweightProfile(
                ephemeralToken: token,
                publicProfileId: publicId,
                displayName: profile.displayName,
                bioShort: nil,
                primarySNSLabel: profile.primarySNSLabel,
                primarySNSURL: profile.primarySNSURL,
                profileVersion: profile.profileVersion,
                iconThumbnailData: thumb
            )
            try await env.nearby.sendLightweightProfile(light, exchangeId: exchangeId)
            try await env.tokenRepository.consumeOutgoingTokenForSession(exchangeId)
            checkReadyForComplete()
        } catch {
            hasSentMyProfile = false
            errorMessage = error.localizedDescription
        }
    }

    private func checkReadyForComplete() {
        guard hasSentMyProfile, receivedPeerProfile != nil else { return }
        guard let sid = sessionEntityId else { return }
        showExchangeComplete = true
        exchangeTimeoutTask?.cancel()
        exchangeTimeoutTask = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            try? await env?.exchangeSessionRepository.updateSessionState(id: sid, state: .saving)
        }
    }

    private func resetExchangeFlow() {
        exchangeTimeoutTask?.cancel()
        exchangeTimeoutTask = nil
        sessionEntityId = nil
        confirmationCode = nil
        localUserApproved = false
        peerHasApproved = false
        hasSentMyProfile = false
        receivedPeerProfile = nil
        receivedPeerIsDuplicate = false
        showExchangeComplete = false
        showIncomingInviteSheet = false
    }

    private func publicProfileIdForInvite(profile: ProfileSummary?, environment: AppEnvironment) async -> String? {
        guard let profile else { return nil }
        if let existing = Self.trimmedPublicProfileId(profile.publicProfileId) {
            return existing
        }
        do {
            return try await environment.profileRepository.ensurePublicProfileId()
        } catch {
            AppLogger.log("ensurePublicProfileId failed in sendInvite: \(error.localizedDescription)", category: "Exchange")
            return nil
        }
    }

    private static func trimmedPublicProfileId(_ value: String?) -> String? {
        let trimmed = value?.trimmedCoscard() ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalizedPublicProfileId(_ value: String?) -> String? {
        trimmedPublicProfileId(value)?.lowercased()
    }
}
