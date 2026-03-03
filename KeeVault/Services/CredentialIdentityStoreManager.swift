@preconcurrency import AuthenticationServices
import OSLog

enum CredentialIdentityStoreManager: Sendable {
    private static let logger = Logger(subsystem: "KeeVault", category: "CredentialIdentityStore")

    static func populate(with entries: [KPEntry]) {
        Task {
            let store = ASCredentialIdentityStore.shared
            let state = await store.state()
            guard state.isEnabled else {
                logger.info("Identity store is not enabled; skipping populate")
                return
            }

            let identities = entries.compactMap(passwordIdentity(for:))
            let skippedCount = entries.count - identities.count
            if skippedCount > 0 {
                logger.info("Skipped \(skippedCount) entries with no extractable domain")
            }
            guard !identities.isEmpty else {
                logger.info("No credential identities to populate")
                return
            }

            do {
                try await store.replaceCredentialIdentities(identities)
                logger.info("Populated identity store with \(identities.count) identities")
            } catch {
                logger.error("Failed to replace credential identities: \(error.localizedDescription)")
            }
        }
    }

    static func clearStore() {
        Task {
            let store = ASCredentialIdentityStore.shared
            let state = await store.state()
            guard state.isEnabled else { return }

            do {
                try await store.removeAllCredentialIdentities()
                logger.info("Cleared all credential identities")
            } catch {
                logger.error("Failed to clear credential identities: \(error.localizedDescription)")
            }
        }
    }

    static func removeIdentities(for entries: [KPEntry]) {
        Task {
            let store = ASCredentialIdentityStore.shared
            let state = await store.state()
            guard state.isEnabled else { return }

            let identities = entries.compactMap(passwordIdentity(for:))
            guard !identities.isEmpty else { return }

            do {
                try await store.removeCredentialIdentities(identities)
            } catch {
                logger.error("Failed to remove credential identities: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Internal (visible to tests via @testable import)

    static func passwordIdentity(for entry: KPEntry) -> ASPasswordCredentialIdentity? {
        let username = entry.username.isEmpty ? entry.title : entry.username
        guard !username.isEmpty else { return nil }
        guard entry.hasPassword else { return nil }

        let allURLs = [entry.url] + entry.additionalURLs
        let domain = allURLs.lazy.compactMap(domainFromURLString).first
        guard let domain else { return nil }

        let serviceIdentifier = ASCredentialServiceIdentifier(identifier: domain, type: .domain)
        return ASPasswordCredentialIdentity(
            serviceIdentifier: serviceIdentifier,
            user: username,
            recordIdentifier: entry.id.uuidString
        )
    }

    static func domainFromURLString(_ urlString: String) -> String? {
        guard !urlString.isEmpty else { return nil }

        let host: String?
        if let h = URL(string: urlString)?.host {
            host = h
        } else {
            host = URL(string: "https://\(urlString)")?.host
        }

        guard let host else { return nil }
        return registeredDomain(from: host)
    }

    // MARK: - Registered domain extraction

    /// Extracts the registered domain (eTLD+1) from a host string.
    /// Strips `www.` prefix and collapses subdomains to the base domain.
    /// Returns nil for IP addresses, localhost, and single-label hosts.
    static func registeredDomain(from host: String) -> String? {
        let lowered = host.lowercased()

        // Skip IPv6
        if lowered.contains(":") { return nil }

        let labels = lowered.split(separator: ".").map(String.init)

        // Skip single-label hosts (localhost, etc.)
        guard labels.count >= 2 else { return nil }

        // Skip IP addresses (all labels are numeric)
        if labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return nil }

        // Strip www prefix
        var effective = labels
        if effective.first == "www" {
            effective.removeFirst()
        }
        guard effective.count >= 2 else { return nil }

        // Check for known multi-part TLDs (co.uk, com.au, etc.)
        let lastTwo = effective.suffix(2).joined(separator: ".")
        if Self.knownMultiPartTLDs.contains(lastTwo) {
            guard effective.count >= 3 else { return nil }
            return effective.suffix(3).joined(separator: ".")
        }

        return effective.suffix(2).joined(separator: ".")
    }

    private static let knownMultiPartTLDs: Set<String> = [
        "co.uk", "org.uk", "ac.uk", "gov.uk", "me.uk", "net.uk",
        "com.au", "org.au", "net.au", "edu.au",
        "co.nz", "org.nz", "net.nz",
        "co.jp", "or.jp", "ne.jp", "ac.jp",
        "com.br", "org.br", "net.br",
        "co.in", "org.in", "net.in",
        "co.za", "org.za", "net.za",
        "com.mx", "org.mx",
        "co.kr", "or.kr",
        "com.cn", "org.cn", "net.cn",
        "com.tw", "org.tw", "net.tw",
        "co.il", "org.il",
        "com.sg", "org.sg",
        "com.hk", "org.hk",
        "co.th", "or.th",
        "com.tr", "org.tr",
        "com.ar", "org.ar",
        "co.id",
        "com.ph",
        "com.my",
        "com.ng",
        "co.ke",
    ]
}
