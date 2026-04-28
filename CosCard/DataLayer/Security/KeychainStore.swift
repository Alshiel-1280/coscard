import Foundation
import Security

enum KeychainStore {
    enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case unexpectedItemData
    }

    static func save(_ data: Data, service: String, account: String) throws {
        let addStatus = SecItemAdd(addQuery(data: data, service: service, account: account) as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try update(data, service: service, account: account)
        default:
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    static func load(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError.unexpectedItemData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func update(_ data: Data, service: String, account: String) throws {
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            baseQuery(service: service, account: account) as CFDictionary,
            attributes as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let retryStatus = SecItemAdd(addQuery(data: data, service: service, account: account) as CFDictionary, nil)
            if retryStatus == errSecSuccess {
                return
            }
            if retryStatus == errSecDuplicateItem {
                let retryUpdateStatus = SecItemUpdate(
                    baseQuery(service: service, account: account) as CFDictionary,
                    attributes as CFDictionary
                )
                if retryUpdateStatus == errSecSuccess {
                    return
                }
                throw KeychainError.unexpectedStatus(retryUpdateStatus)
            }
            throw KeychainError.unexpectedStatus(retryStatus)
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func addQuery(data: Data, service: String, account: String) -> [String: Any] {
        var query = baseQuery(service: service, account: account)
        query[kSecValueData as String] = data
        #if !os(macOS)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        return query
    }
}
