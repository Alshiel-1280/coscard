import Foundation
import XCTest
@testable import CosCard

final class KeychainStoreTests: XCTestCase {
    private var storedKeys: [(service: String, account: String)] = []

    override func tearDownWithError() throws {
        for key in storedKeys {
            try? KeychainStore.delete(service: key.service, account: key.account)
        }
        storedKeys.removeAll()
        try super.tearDownWithError()
    }

    func testLoadMissingItemReturnsNil() throws {
        let key = makeKey()

        XCTAssertNil(try KeychainStore.load(service: key.service, account: key.account))
    }

    func testSaveAndLoadRoundTrip() throws {
        let key = makeKey()
        let data = try XCTUnwrap("secret-value".data(using: .utf8))

        try KeychainStore.save(data, service: key.service, account: key.account)

        XCTAssertEqual(try KeychainStore.load(service: key.service, account: key.account), data)
    }

    func testSaveOverwritesExistingItem() throws {
        let key = makeKey()
        let first = try XCTUnwrap("first".data(using: .utf8))
        let second = try XCTUnwrap("second".data(using: .utf8))

        try KeychainStore.save(first, service: key.service, account: key.account)
        try KeychainStore.save(second, service: key.service, account: key.account)

        XCTAssertEqual(try KeychainStore.load(service: key.service, account: key.account), second)
    }

    func testDeleteRemovesItem() throws {
        let key = makeKey()
        let data = try XCTUnwrap("delete-me".data(using: .utf8))

        try KeychainStore.save(data, service: key.service, account: key.account)
        try KeychainStore.delete(service: key.service, account: key.account)

        XCTAssertNil(try KeychainStore.load(service: key.service, account: key.account))
    }

    func testDeleteMissingItemDoesNotThrow() throws {
        let key = makeKey()

        XCTAssertNoThrow(try KeychainStore.delete(service: key.service, account: key.account))
    }

    private func makeKey() -> (service: String, account: String) {
        let service = "jp.coscard.tests.keychain.\(UUID().uuidString)"
        let account = UUID().uuidString
        storedKeys.append((service, account))
        return (service, account)
    }
}
