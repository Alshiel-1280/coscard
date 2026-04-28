import Foundation
import MultipeerConnectivity

/// MultipeerConnectivity の集約。交換状態は state machine 前提で段階的に拡張する。
@MainActor
final class MPCManager: NSObject, NearbyServiceProtocol {
    private static let serviceType = "coscard"
    private static let discoveryPreviewNameKey = "previewName"
    private static let localPeerIDDefaultsKey = "coscard.mpc.localPeerID"

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var peerByKey: [String: MCPeerID] = [:]
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?
    private var connectedPeer: MCPeerID?

    private(set) var exchangeState: ExchangeState = .idle
    private(set) var candidates: [PeerCandidate] = []
    var incomingInvitePreviewName: String?
    var onEnvelopeReceived: ((WireEnvelope) -> Void)?

    private(set) var activeExchangeId: UUID?
    private(set) var isInviteInitiator = false
    private(set) var pendingInvitationExchangeId: UUID?
    var onSessionConnected: (() -> Void)?
    var onPeerDisconnected: (() -> Void)?
    var onPermissionError: ((String) -> Void)?
    var inviteAutoRejectPredicate: ((String?, String?) -> Bool)?

    override init() {
        super.init()
    }

    func startAdvertisingAndBrowsing(displayName: String) async throws {
        stopInternals()
        let trimmed = displayName.trimmedCoscard()
        let peer = MCPeerID(displayName: Self.makeLocalPeerDisplayName())
        myPeerID = peer
        let sess = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        sess.delegate = self
        session = sess

        let info = [Self.discoveryPreviewNameKey: trimmed]
        let adv = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: info, serviceType: Self.serviceType)
        let br = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        adv.delegate = self
        br.delegate = self
        advertiser = adv
        browser = br
        adv.startAdvertisingPeer()
        br.startBrowsingForPeers()
        exchangeState = .browsing
    }

    func stop() async {
        stopInternals()
    }

    private func stopInternals() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        pendingInvitationHandler?(false, nil)
        advertiser = nil
        browser = nil
        session?.disconnect()
        session = nil
        myPeerID = nil
        peerByKey.removeAll()
        candidates.removeAll()
        pendingInvitationHandler = nil
        connectedPeer = nil
        incomingInvitePreviewName = nil
        activeExchangeId = nil
        isInviteInitiator = false
        pendingInvitationExchangeId = nil
        exchangeState = .idle
    }

    func sendInvite(
        to candidate: PeerCandidate,
        previewName: String,
        previewIcon: Data?,
        publicProfileId: String?,
        exchangeId: UUID
    ) async throws {
        guard let browser, let session else { throw CosCardError.sessionMissing }
        guard let peer = peerByKey[candidate.mpcPeerId] else { throw CosCardError.peerNotFound }
        activeExchangeId = exchangeId
        isInviteInitiator = true
        let payload = InvitePayload(
            requesterPreviewName: previewName,
            requesterPreviewIconData: previewIcon,
            publicProfileId: publicProfileId
        )
        let ctx = try MPCMessageEncoder.encodeEnvelope(messageType: .invite, exchangeId: exchangeId, payload: payload)
        browser.invitePeer(peer, to: session, withContext: ctx, timeout: 60)
        exchangeState = .invitationSent
    }

    func acceptInvite() async throws {
        guard let handler = pendingInvitationHandler else { return }
        pendingInvitationHandler = nil
        pendingInvitationExchangeId = nil
        handler(true, session)
        exchangeState = .awaitingPeerApproval
    }

    func rejectInvite() async throws {
        guard let handler = pendingInvitationHandler else { return }
        pendingInvitationHandler = nil
        pendingInvitationExchangeId = nil
        activeExchangeId = nil
        incomingInvitePreviewName = nil
        handler(false, nil)
        exchangeState = candidates.isEmpty ? .browsing : .candidateFound
    }

    func sendConfirmationCode(_ code: String, exchangeId: UUID) async throws {
        let payload = ConfirmationCodePayload(code: code)
        try sendToConnectedPeers(
            messageType: .confirmationCode,
            exchangeId: exchangeId,
            payload: payload
        )
    }

    func sendApproval(approved: Bool, exchangeId: UUID) async throws {
        let payload = ApprovalStatePayload(approved: approved, approvedAt: .now)
        try sendToConnectedPeers(
            messageType: .approvalState,
            exchangeId: exchangeId,
            payload: payload
        )
    }

    func sendLightweightProfile(_ profile: LightweightProfile, exchangeId: UUID) async throws {
        let payload = LightweightProfilePayload(
            ephemeralToken: profile.ephemeralToken,
            publicProfileId: profile.publicProfileId,
            displayName: profile.displayName,
            bioShort: profile.bioShort,
            primarySNSLabel: profile.primarySNSLabel,
            primarySNSURL: profile.primarySNSURL,
            profileVersion: profile.profileVersion,
            iconThumbnailData: profile.iconThumbnailData
        )
        let expiresAt = Date().addingTimeInterval(180)
        try sendToConnectedPeers(
            messageType: .lightweightProfile,
            exchangeId: exchangeId,
            payload: payload,
            expiresAt: expiresAt
        )
    }

    func sendAck(exchangeId: UUID, message: String?) async throws {
        let payload = AckPayload(receivedAt: .now, message: message)
        try sendToConnectedPeers(
            messageType: .ack,
            exchangeId: exchangeId,
            payload: payload
        )
    }

    func cancel(reason: String?) async throws {
        guard let session else { return }
        let peers = session.connectedPeers
        if !peers.isEmpty, let exchangeId = activeExchangeId {
            let payload = CancelPayload(cancelledAt: .now, reason: reason)
            let data = try MPCMessageEncoder.encodeEnvelope(messageType: .cancel, exchangeId: exchangeId, payload: payload)
            try session.send(data, toPeers: peers, with: .reliable)
        }
        session.disconnect()
        connectedPeer = nil
        exchangeState = .cancelled
    }

    func markExchangeReadyForSave(exchangeId: UUID) async {
        guard activeExchangeId == exchangeId || pendingInvitationExchangeId == exchangeId else { return }
        activeExchangeId = nil
        pendingInvitationExchangeId = nil
        incomingInvitePreviewName = nil
        isInviteInitiator = false
        connectedPeer = nil
        exchangeState = candidates.isEmpty ? .browsing : .candidateFound
    }

    private func sendToConnectedPeers<P: Encodable>(
        messageType: WireMessageType,
        exchangeId: UUID,
        payload: P,
        expiresAt: Date? = nil
    ) throws {
        guard let session else { throw CosCardError.sessionMissing }
        let peers = session.connectedPeers
        let peer: MCPeerID?
        if let connectedPeer, peers.contains(connectedPeer) {
            peer = connectedPeer
        } else {
            peer = peers.first
            connectedPeer = peer
        }
        guard let peer else { throw CosCardError.notConnected }
        let data = try MPCMessageEncoder.encodeEnvelope(
            messageType: messageType,
            exchangeId: exchangeId,
            payload: payload,
            expiresAt: expiresAt
        )
        try session.send(data, toPeers: [peer], with: .reliable)
    }

    private static func makeLocalPeerDisplayName() -> String {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: localPeerIDDefaultsKey), !saved.isEmpty {
            return "CosCard-\(saved)"
        }
        let generated = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefix(12)
        let id = String(generated)
        defaults.set(id, forKey: localPeerIDDefaultsKey)
        return "CosCard-\(id)"
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            AppLogger.log("Advertising failed: \(error.localizedDescription)", category: "MPC")
            let msg =
                "近傍の公開に失敗しました。設定 > プライバシーとセキュリティ > ローカルネットワークで CosCard を許可してください。（\(error.localizedDescription)）"
            self.onPermissionError?(msg)
        }
    }

    nonisolated func advertiser(
        _: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer _: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            guard let context else {
                invitationHandler(false, nil)
                return
            }
            guard let wireEnv = try? MPCMessageEncoder.decodeEnvelope(context) else {
                invitationHandler(false, nil)
                return
            }
            guard wireEnv.messageType == .invite else {
                invitationHandler(false, nil)
                AppLogger.log("Invite rejected: unexpected message type \(wireEnv.messageType.rawValue)", category: "MPC")
                return
            }
            if let expiresAt = wireEnv.expiresAt, expiresAt < Date() {
                invitationHandler(false, nil)
                AppLogger.log("Invite rejected: expired context", category: "MPC")
                return
            }
            let decodedExchangeId = wireEnv.exchangeId
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            guard let invite = try? dec.decode(InvitePayload.self, from: wireEnv.payload) else {
                invitationHandler(false, nil)
                AppLogger.log("Invite rejected: invalid invite payload", category: "MPC")
                return
            }
            let previewName = invite.requesterPreviewName
            let publicProfileId = invite.publicProfileId
            if self.inviteAutoRejectPredicate?(previewName, publicProfileId) == true {
                invitationHandler(false, nil)
                AppLogger.log("Invite auto-rejected (blocked invite identity)", category: "MPC")
                return
            }
            self.pendingInvitationHandler = invitationHandler
            self.exchangeState = .invitationReceived
            self.activeExchangeId = decodedExchangeId
            self.pendingInvitationExchangeId = decodedExchangeId
            self.isInviteInitiator = false
            self.incomingInvitePreviewName = previewName
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            AppLogger.log("Browsing failed: \(error.localizedDescription)", category: "MPC")
            let msg =
                "近くの端末の検索に失敗しました。Bluetooth とローカルネットワークの許可を確認してください。（\(error.localizedDescription)）"
            self.onPermissionError?(msg)
        }
    }

    nonisolated func browser(_: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard peerID != self.myPeerID else { return }
            let key = MPCPeerHandle.candidateKey(for: peerID)
            self.peerByKey[key] = peerID
            let preview = info?[Self.discoveryPreviewNameKey] ?? peerID.displayName
            if !self.candidates.contains(where: { $0.mpcPeerId == key }) {
                self.candidates.append(
                    PeerCandidate(
                        mpcPeerId: key,
                        previewDisplayName: preview,
                        previewBioSnippet: nil,
                        previewIconThumbnailData: nil
                    )
                )
            }
            self.exchangeState = .candidateFound
        }
    }

    nonisolated func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard peerID != self.myPeerID else { return }
            let key = MPCPeerHandle.candidateKey(for: peerID)
            self.peerByKey.removeValue(forKey: key)
            self.candidates.removeAll { $0.mpcPeerId == key }
        }
    }
}

// MARK: - MCSessionDelegate

extension MPCManager: MCSessionDelegate {
    nonisolated func session(_ callbackSession: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard self.session === callbackSession else { return }
            switch state {
            case .connected:
                self.connectedPeer = peerID
                self.onSessionConnected?()
            case .notConnected:
                self.pendingInvitationHandler = nil
                if self.connectedPeer == peerID {
                    self.connectedPeer = nil
                }
                if self.exchangeState == .cancelled {
                    self.activeExchangeId = nil
                    self.pendingInvitationExchangeId = nil
                    self.incomingInvitePreviewName = nil
                    self.isInviteInitiator = false
                    self.exchangeState = .idle
                    return
                }
                if self.activeExchangeId != nil || self.pendingInvitationExchangeId != nil {
                    self.activeExchangeId = nil
                    self.pendingInvitationExchangeId = nil
                    self.incomingInvitePreviewName = nil
                    self.isInviteInitiator = false
                    self.exchangeState = .failed
                    self.onPeerDisconnected?()
                }
            default:
                break
            }
        }
    }

    nonisolated func session(_ callbackSession: MCSession, didReceive data: Data, fromPeer _: MCPeerID) {
        Task { @MainActor in
            guard self.session === callbackSession else { return }
            guard let env = try? MPCMessageEncoder.decodeEnvelope(data) else { return }
            self.onEnvelopeReceived?(env)
        }
    }

    nonisolated func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {
        // 未使用（stream 禁止方針）
    }

    nonisolated func session(
        _: MCSession,
        didStartReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        with _: Progress
    ) {
        // 未使用（resource 禁止方針）
    }

    nonisolated func session(
        _: MCSession,
        didFinishReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        at _: URL?,
        withError _: Error?
    ) {
        // 未使用（resource 禁止方針）
    }
}
