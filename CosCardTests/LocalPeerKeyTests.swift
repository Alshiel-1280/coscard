import XCTest
@testable import CosCard

final class LocalPeerKeyTests: XCTestCase {
    func testStableKeyWithPublicProfileId_ignoresEphemeralToken() {
        let a = LightweightProfile(
            ephemeralToken: "tok-a",
            publicProfileId: "pid-stable",
            displayName: "山田",
            profileVersion: 3
        )
        let b = LightweightProfile(
            ephemeralToken: "tok-b",
            publicProfileId: "pid-stable",
            displayName: "山田",
            profileVersion: 3
        )
        XCTAssertEqual(LocalPeerKey.make(from: a), LocalPeerKey.make(from: b))
    }

    func testLegacyFallback_sameIdentityIgnoresEphemeral() {
        let icon = Data("x".utf8)
        let a = LightweightProfile(
            ephemeralToken: "e1",
            displayName: "Bob",
            profileVersion: 2,
            iconThumbnailData: icon
        )
        let b = LightweightProfile(
            ephemeralToken: "e2",
            displayName: "Bob",
            profileVersion: 2,
            iconThumbnailData: icon
        )
        XCTAssertEqual(LocalPeerKey.make(from: a), LocalPeerKey.make(from: b))
    }

    @MainActor
    func testResolveDuplicateCheckWithProfile_reportsDuplicateAndRequiresUserChoice() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "ephemeral-a",
            publicProfileId: "profile-1",
            displayName: "Alice",
            profileVersion: 2
        )
        let expectedKey = LocalPeerKey.make(from: profile)
        let repository = StubPeerRepository(existingKeys: [expectedKey])

        let result = try await ResolveDuplicateExchangeUseCase().check(
            peerProfile: profile,
            peerRepository: repository
        )

        XCTAssertEqual(result.localPeerKey, expectedKey)
        XCTAssertTrue(result.isDuplicate)
        XCTAssertTrue(result.requiresUserChoice)
        XCTAssertEqual(repository.checkedKeys, [expectedKey])
        XCTAssertEqual(repository.checkedPublicProfileIds, ["profile-1"])
    }

    @MainActor
    func testResolveDuplicateCheckWithProfile_reportsDuplicateWhenPublicProfileIdMatchesEvenIfVersionChanged() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "ephemeral-b",
            publicProfileId: " Profile-1 ",
            displayName: "Alice Updated",
            profileVersion: 3
        )
        let expectedKey = LocalPeerKey.make(from: profile)
        let repository = StubPeerRepository(existingPublicProfileIds: ["profile-1"])

        let result = try await ResolveDuplicateExchangeUseCase().check(
            peerProfile: profile,
            peerRepository: repository
        )

        XCTAssertEqual(result.localPeerKey, expectedKey)
        XCTAssertTrue(result.isDuplicate)
        XCTAssertTrue(result.requiresUserChoice)
        XCTAssertEqual(repository.checkedKeys, [expectedKey])
        XCTAssertEqual(repository.checkedPublicProfileIds, ["Profile-1"])
    }

    @MainActor
    func testResolveDuplicateCheckWithLocalPeerKey_reportsNonDuplicateWithoutUserChoice() async throws {
        let repository = StubPeerRepository(existingKeys: [])

        let result = try await ResolveDuplicateExchangeUseCase().check(
            localPeerKey: "new-peer-key",
            peerRepository: repository
        )

        XCTAssertEqual(result.localPeerKey, "new-peer-key")
        XCTAssertFalse(result.isDuplicate)
        XCTAssertFalse(result.requiresUserChoice)
        XCTAssertEqual(repository.checkedKeys, ["new-peer-key"])
        XCTAssertTrue(repository.checkedPublicProfileIds.isEmpty)
    }
}

@MainActor
private final class StubPeerRepository: PeerRepositoryProtocol {
    private let existingKeys: Set<String>
    private let existingPublicProfileIds: Set<String>
    private(set) var checkedKeys: [String] = []
    private(set) var checkedPublicProfileIds: [String] = []

    init(existingKeys: Set<String> = [], existingPublicProfileIds: Set<String> = []) {
        self.existingKeys = existingKeys
        self.existingPublicProfileIds = existingPublicProfileIds
    }

    func hasPeer(withLocalPeerKey key: String) async throws -> Bool {
        checkedKeys.append(key)
        return existingKeys.contains(key)
    }

    func hasPeer(withPublicProfileId publicProfileId: String) async throws -> Bool {
        let trimmed = publicProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
        checkedPublicProfileIds.append(trimmed)
        return existingPublicProfileIds.contains(trimmed.lowercased())
    }

    func listPeers(newestFirst: Bool) async throws -> [PeerSummary] {
        XCTFail("Unexpected listPeers call")
        return []
    }

    func listBlockedPeers(newestFirst: Bool) async throws -> [PeerSummary] {
        XCTFail("Unexpected listBlockedPeers call")
        return []
    }

    func fetchPeer(id: UUID) async throws -> PeerDetail? {
        XCTFail("Unexpected fetchPeer call")
        return nil
    }

    func updateMemo(peerId: UUID, memo: String?) async throws {
        XCTFail("Unexpected updateMemo call")
    }

    func setBlocked(peerId: UUID, blocked: Bool) async throws {
        XCTFail("Unexpected setBlocked call")
    }

    func setHidden(peerId: UUID, hidden: Bool) async throws {
        XCTFail("Unexpected setHidden call")
    }

    func isBlockedLocalPeerKey(_ key: String) async throws -> Bool {
        XCTFail("Unexpected isBlockedLocalPeerKey call")
        return false
    }

    func blockedNormalizedDisplayNames() async throws -> Set<String> {
        XCTFail("Unexpected blockedNormalizedDisplayNames call")
        return []
    }

    func blockedPublicProfileIds() async throws -> Set<String> {
        XCTFail("Unexpected blockedPublicProfileIds call")
        return []
    }

    func upsertPeerFromExchange(
        localPeerKey: String,
        received: LightweightProfile,
        memo: String?,
        eventTag: String?
    ) async throws -> UUID {
        XCTFail("Unexpected upsertPeerFromExchange call")
        return UUID()
    }
}
