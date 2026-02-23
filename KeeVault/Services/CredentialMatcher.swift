import AuthenticationServices

enum CredentialMatcher {
    static func matchedEntries(from entries: [KPEntry], for identifiers: [ASCredentialServiceIdentifier]) -> [KPEntry] {
        guard !identifiers.isEmpty else { return entries }

        let searchTerms = Set(identifiers.compactMap(searchTerm(for:)).map { $0.lowercased() })

        return entries.filter { entry in
            let entryHost = hostFromURLString(entry.url)?.lowercased()
            let entryURL = entry.url.lowercased()
            let entryTitle = entry.title.lowercased()

            return searchTerms.contains { term in
                if let entryHost, entryHost == term || entryHost.hasSuffix(".\(term)") {
                    return true
                }

                return entryURL.contains(term) || entryTitle.contains(term)
            }
        }
    }

    static func searchTerm(for identifier: ASCredentialServiceIdentifier) -> String? {
        if identifier.type == .domain {
            return identifier.identifier
        }

        return hostFromURLString(identifier.identifier) ?? identifier.identifier
    }

    static func hostFromURLString(_ value: String) -> String? {
        if let host = URL(string: value)?.host {
            return host
        }

        return URL(string: "https://\(value)")?.host
    }
}
