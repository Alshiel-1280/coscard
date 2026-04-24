import Foundation

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
            }
        }
        environment.nearby.onSessionConnected = { [weak self] in
            Task { @MainActor in
                self?.onMPCSessionConnected()
            }
        }
        environment.nearby.onPeerDisconnected = { [weak self] in
            Task { @MainActor in
                self?.handlePeerDisconnected()
            }
        }
        Task { await refreshInviteBlockList(environment) }
    }

    private func refreshInviteBlockList(_ environment: AppEnvironment) async {
        let blocked = (try? await environment.peerRepository.blockedNormalizedDisplayNames()) ?? []
        environment.nearby.inviteAutoRejectPredicate = { preview in
            guard let p = preview?.trimmedCoscard(), !p.isEmpty else { return false }
            return blocked.contains(p.normalizedForPeerKey())
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
        let profile = try? await env.profileRepository.fetchCurrentProfile()
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
        await StopExchangeUseCase(nearby: env.nearby).execute()
        resetExchangeFlow()
        syncFromNearby()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { self?.syncFromNearby() }
            }
        }
    }

    func syncFromNearby() {
        guard let env else { return }
        candidates = env.nearby.candidates
        exchangeState = env.nearby.exchangeState
        incomingPreviewName = env.nearby.incomingInvitePreviewName
        if env.nearby.exchangeState == .invitationReceived, env.nearby.incomingInvitePreviewName != nil, !showExchangeComplete {
            showIncomingInviteSheet = true
        }
    }

    func sendInvite(to candidate: PeerCandidate) async {
        guard let env else { return }
        errorMessage = nil
        let exchangeId = UUID()
        sessionEntityId = exchangeId
        let profile = try? await env.profileRepository.fetchCurrentProfile()
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

    func finalizeExchange(memo: String?, eventTag: String?) async {
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
                confirmationCode: confirmationCode
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
        guard sessionEntityId != nil else { return }
        errorMessage = "接続が切断されました"
        resetExchangeFlow()
        syncFromNearby()
    }

    private func scheduleExchangeTimeout() {
        exchangeTimeoutTask?.cancel()
        exchangeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            await MainActor.run {
                guard let self else { return }
                guard self.sessionEntityId != nil else { return }
                guard !self.showExchangeComplete else { return }
                self.errorMessage = "交換がタイムアウトしました"
                self.resetExchangeFlow()
                Task { try? await self.env?.nearby.cancel(reason: "timeout") }
                self.syncFromNearby()
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
                receivedPeerProfile = LightweightProfile(
                    ephemeralToken: p.ephemeralToken,
                    displayName: p.displayName,
                    bioShort: p.bioShort,
                    primarySNSLabel: p.primarySNSLabel,
                    primarySNSURL: p.primarySNSURL,
                    profileVersion: p.profileVersion,
                    iconThumbnailData: p.iconThumbnailData
                )
                checkReadyForComplete()
            case .cancel:
                errorMessage = "相手がキャンセルしました"
                resetExchangeFlow()
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
            let thumb = profile.iconThumbnailData
            let light = LightweightProfile(
                ephemeralToken: token,
                displayName: profile.displayName,
                bioShort: profile.bio,
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
        showExchangeComplete = false
        showIncomingInviteSheet = false
    }
}
