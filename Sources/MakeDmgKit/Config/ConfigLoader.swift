import Foundation

public enum ConfigLoader {
    public static func load(from url: URL) throws -> LoadedConfig {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigError.unreadable(path: url.path, reason: error.localizedDescription)
        }
        return try load(data: data, fileURL: url)
    }

    /// Decodes config data; fileURL is only used as the base for relative paths.
    public static func load(data: Data, fileURL: URL) throws -> LoadedConfig {
        // Parse once untyped for readable syntax errors and unknown-key checks.
        let root: [String: Any]
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dict = object as? [String: Any] else {
                throw ConfigError.invalidJSON(reason: "the root must be an object")
            }
            root = dict
        } catch let error as ConfigError {
            throw error
        } catch {
            let ns = error as NSError
            let reason = ns.userInfo[NSDebugDescriptionErrorKey] as? String ?? ns.localizedDescription
            throw ConfigError.invalidJSON(reason: reason)
        }

        let unknown = unknownKeyIssues(in: root)

        let config: DMGConfig
        do {
            config = try JSONDecoder().decode(DMGConfig.self, from: data)
        } catch let error as DecodingError {
            throw ConfigError.from(error, notes: unknown.map(\.description))
        }

        return LoadedConfig(config: config, fileURL: fileURL.standardizedFileURL, loadIssues: unknown)
    }

    // MARK: - Unknown keys

    static func unknownKeyIssues(in root: [String: Any]) -> [ConfigIssue] {
        var issues: [ConfigIssue] = []
        check(root, known: DMGConfig.knownKeys, path: "", into: &issues)

        let sections: [(String, Set<String>)] = [
            ("window", WindowConfig.knownKeys),
            ("icon", IconConfig.knownKeys),
            ("background", Background.knownKeys),
            ("sign", SignConfig.knownKeys),
            ("notarize", NotarizeConfig.knownKeys),
        ]
        for (key, known) in sections {
            if let dict = root[key] as? [String: Any] {
                check(dict, known: known, path: key, into: &issues)
            }
        }

        if let items = root["contents"] as? [Any] {
            for (index, item) in items.enumerated() {
                if let dict = item as? [String: Any] {
                    check(dict, known: ContentItem.knownKeys, path: "contents[\(index)]", into: &issues)
                }
            }
        }
        return issues
    }

    private static func check(_ dict: [String: Any], known: Set<String>, path: String, into issues: inout [ConfigIssue]) {
        for key in dict.keys.sorted() where !known.contains(key) {
            var message = "unknown key '\(key)' is ignored"
            if let suggestion = closestMatch(to: key, in: known) {
                message += ", did you mean '\(suggestion)'?"
            }
            issues.append(.warning(path, message))
        }
    }

    /// Nearest known key within edit distance 2, compared case-insensitively.
    static func closestMatch(to key: String, in candidates: Set<String>) -> String? {
        let lowered = key.lowercased()
        let scored = candidates
            .map { ($0, editDistance(lowered, $0.lowercased())) }
            .filter { $0.1 <= 2 }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }
        return scored.first?.0
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
