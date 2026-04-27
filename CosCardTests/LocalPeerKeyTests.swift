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
}
