import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class ProfileRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: ProfileRepository!

    override func setUp() async throws {
        container = try ModelContainerProvider.makePreviewContainer()
        context = ModelContext(container)
        repo = ProfileRepository(modelContext: context)
    }

    func testUpsertStoresCosplayCharacterAndBusinessCardSnapshot() async throws {
        let imageData = Data([0x01, 0x02, 0x03])
        let summary = try await repo.upsertProfile(
            ProfileDraft(
                displayName: "テストユーザー",
                cosplayCharacterName: "テストキャラ",
                bio: "テストbio",
                primarySNSLabel: nil,
                primarySNSURL: nil,
                twitterURL: "cos_x",
                instagramURL: "cos_ig",
                tiktokURL: "cos_tt",
                iconThumbnailData: Data([0x09]),
                businessCardImageData: imageData
            )
        )

        XCTAssertEqual(summary.cosplayCharacterName, "テストキャラ")
        XCTAssertEqual(summary.bio, "テストbio")
        XCTAssertEqual(summary.primarySNSLabel, "X")
        XCTAssertEqual(summary.primarySNSURL, "cos_x")
        XCTAssertEqual(summary.twitterURL, "cos_x")
        XCTAssertEqual(summary.instagramURL, "cos_ig")
        XCTAssertEqual(summary.tiktokURL, "cos_tt")
        XCTAssertEqual(summary.iconThumbnailData, Data([0x09]))
        XCTAssertEqual(summary.businessCardImageData, imageData)

        let history = try await repo.listBusinessCardHistory(newestFirst: true)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.cosplayCharacterName, "テストキャラ")
        XCTAssertEqual(history.first?.businessCardImageData, imageData)
    }

    func testManualBusinessCardSnapshotCanBeSaved() async throws {
        let imageData = Data([0x0A, 0x0B])

        let item = try await repo.saveBusinessCardSnapshot(
            cosplayCharacterName: "手動キャラ",
            imageData: imageData
        )

        let history = try await repo.listBusinessCardHistory(newestFirst: true)
        XCTAssertEqual(history.map(\.id), [item.id])
        XCTAssertEqual(history.first?.cosplayCharacterName, "手動キャラ")
        XCTAssertEqual(history.first?.businessCardImageData, imageData)
    }

    func testUpsertDoesNotDuplicateBusinessCardHistoryWhenImageIsUnchanged() async throws {
        let imageData = Data([0x01, 0x02, 0x03])
        _ = try await repo.upsertProfile(
            ProfileDraft(
                displayName: "初回",
                cosplayCharacterName: "キャラA",
                twitterURL: "cos_x",
                businessCardImageData: imageData
            )
        )
        _ = try await repo.upsertProfile(
            ProfileDraft(
                displayName: "SNS更新",
                cosplayCharacterName: "キャラA",
                twitterURL: "cos_x_2",
                businessCardImageData: imageData
            )
        )

        let history = try await repo.listBusinessCardHistory(newestFirst: true)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.businessCardImageData, imageData)
    }

    func testUpsertAddsBusinessCardHistoryWhenImageChanges() async throws {
        let firstImage = Data([0x01, 0x02, 0x03])
        let secondImage = Data([0x04, 0x05, 0x06])
        _ = try await repo.upsertProfile(
            ProfileDraft(
                displayName: "初回",
                cosplayCharacterName: "キャラA",
                businessCardImageData: firstImage
            )
        )
        _ = try await repo.upsertProfile(
            ProfileDraft(
                displayName: "更新",
                cosplayCharacterName: "キャラB",
                businessCardImageData: secondImage
            )
        )

        let history = try await repo.listBusinessCardHistory(newestFirst: true)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(Set(history.compactMap(\.businessCardImageData)), Set([firstImage, secondImage]))
    }
}
