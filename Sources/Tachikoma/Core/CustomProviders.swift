import Foundation

// MARK: - Custom Providers Registry

public struct CustomProviderInfo: Sendable {
    public enum Kind: String, Sendable { case openai, anthropic }
    public let id: String
    public let kind: Kind
    public let baseURL: String
    public let headers: [String: String]
    public let models: [String: String] // map of alias->modelId (optional usage)
}

public final class CustomProviderRegistry: @unchecked Sendable {
    public static let shared = CustomProviderRegistry()
    private let lock = NSLock()
    private var providers: [String: CustomProviderInfo] = [:]

    private init() {}

    // Load from ~/.<profile>/config.json customProviders
    public func loadFromProfile() {
        guard let json = Self.loadRawConfigJSON() else { return }
        guard let cp = json["customProviders"] as? [String: Any] else { return }
        var out: [String: CustomProviderInfo] = [:]
        for (id, anyVal) in cp {
            guard let dict = anyVal as? [String: Any] else { continue }
            let typeStr = (dict["type"] as? String)?.lowercased() ?? "openai"
            let kind: CustomProviderInfo.Kind = (typeStr == "anthropic") ? .anthropic : .openai
            guard let options = dict["options"] as? [String: Any], let baseURL = options["baseURL"] as? String else { continue }
            let headers = options["headers"] as? [String: String] ?? [:]
            var models: [String: String] = [:]
            if let modelsDict = dict["models"] as? [String: Any] {
                for (k, v) in modelsDict {
                    if let m = (v as? [String: Any])?["name"] as? String { models[k] = m }
                }
            }
            out[id] = CustomProviderInfo(id: id, kind: kind, baseURL: baseURL, headers: headers, models: models)
        }
        lock.lock(); defer { lock.unlock() }
        self.providers = out
    }

    public func list() -> [String: CustomProviderInfo] { lock.lock(); defer { lock.unlock() }; return providers }

    public func get(_ id: String) -> CustomProviderInfo? { lock.lock(); defer { lock.unlock() }; return providers[id] }

    // MARK: - Helpers
    private static func profileDirectoryPath() -> String {
        #if os(Windows)
        let home = ProcessInfo.processInfo.environment["USERPROFILE"] ?? ""
        #else
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        #endif
        return "\(home)/\(TachikomaConfiguration.profileDirectoryName)"
    }

    private static func profileConfigPath() -> String { "\(profileDirectoryPath())/config.json" }

    private static func stripJSONComments(from json: String) -> String {
        var result = ""; var inString = false; var escape = false; var inSL = false; var inML = false
        let chars = Array(json); var i = 0
        while i < chars.count {
            let c = chars[i]; let n: Character? = i+1 < chars.count ? chars[i+1] : nil
            if escape { result.append(c); escape = false; i += 1; continue }
            if c == "\\" && inString { escape = true; result.append(c); i += 1; continue }
            if c == "\"" && !inSL && !inML { inString.toggle(); result.append(c); i += 1; continue }
            if inString { result.append(c); i += 1; continue }
            if c == "/" && n == "/" && !inML { inSL = true; i += 2; continue }
            if c == "/" && n == "*" && !inSL { inML = true; i += 2; continue }
            if c == "\n" && inSL { inSL = false; result.append(c); i += 1; continue }
            if c == "*" && n == "/" && inML { inML = false; i += 2; continue }
            if !inSL && !inML { result.append(c) }
            i += 1
        }
        return result
    }

    private static func expandEnvironmentVariables(in text: String) -> String {
        let pattern = #"\$\{([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed()
        for m in matches {
            let nameRange = m.range(at: 1)
            let fullRange = m.range(at: 0)
            if nameRange.location != NSNotFound, let swiftName = Range(nameRange, in: text), let swiftFull = Range(fullRange, in: text) {
                let name = String(text[swiftName])
                if let val = ProcessInfo.processInfo.environment[name] {
                    result.replaceSubrange(swiftFull, with: val)
                }
            }
        }
        return result
    }

    private static func loadRawConfigJSON() -> [String: Any]? {
        let path = profileConfigPath()
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        do {
            let raw = try String(contentsOfFile: path)
            let cleaned = stripJSONComments(from: raw)
            let expanded = expandEnvironmentVariables(in: cleaned)
            if let data = expanded.data(using: .utf8) {
                return try JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
        } catch { }
        return nil
    }
}
