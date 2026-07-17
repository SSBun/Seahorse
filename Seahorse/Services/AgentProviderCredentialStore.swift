import Foundation
import Security

/// Stores compatible-provider API tokens in the system Keychain.
struct AgentProviderCredentialStore {
    private let service = "com.csl.cool.Seahorse.agent-providers"

    /// Returns the token saved for a provider, if present.
    func token(for providerID: String) -> String? {
        var query = baseQuery(for: providerID)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Saves or replaces the token for a provider.
    func setToken(_ token: String, for providerID: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery(for: providerID)
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if status == errSecSuccess { return }

        guard status == errSecItemNotFound else {
            throw keychainError(status)
        }
        var item = query
        item[kSecValueData] = data
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError(addStatus)
        }
    }

    /// Removes the token saved for a provider.
    func removeToken(for providerID: String) throws {
        let status = SecItemDelete(baseQuery(for: providerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private func baseQuery(for providerID: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: providerID
        ]
    }

    private func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
