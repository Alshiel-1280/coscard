import Foundation

/// 将来のトークン・鍵保存用。MVP ではスタブ。
enum KeychainStore {
    enum KeychainError: Error {
        case unimplemented
    }

    static func save(_: Data, service _: String, account _: String) throws {
        // TODO: SecItemAdd / SecItemUpdate
        throw KeychainError.unimplemented
    }

    static func load(service _: String, account _: String) throws -> Data? {
        // TODO: SecItemCopyMatching
        nil
    }
}
