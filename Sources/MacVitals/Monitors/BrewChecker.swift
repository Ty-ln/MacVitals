import Foundation

struct OutdatedPackage: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let installed: String
    let latest: String
}

struct BrewResult {
    var formulae: [OutdatedPackage] = []
    var casks: [OutdatedPackage] = []
    var count: Int { formulae.count + casks.count }
}

/// Runs `brew update` then `brew outdated --json=v2`. Read only: it never upgrades anything.
enum BrewChecker {
    static let brewPath: String? = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        .first { FileManager.default.isExecutableFile(atPath: $0) }

    enum Failure: LocalizedError {
        case notInstalled, failed(String)
        var errorDescription: String? {
            switch self {
            case .notInstalled: "Homebrew isn't installed."
            case .failed(let message): message
            }
        }
    }

    static func check() -> Result<BrewResult, Failure> {
        guard let brew = brewPath else { return .failure(.notInstalled) }
        let prefix = (brew as NSString).deletingLastPathComponent
        let env = [
            "PATH": "\(prefix):/usr/bin:/bin:/usr/sbin:/sbin",
            "HOMEBREW_NO_ANALYTICS": "1",
            "HOMEBREW_NO_ENV_HINTS": "1",
            "HOMEBREW_NO_COLOR": "1",
        ]

        // A failed update (offline) still leaves usable local metadata, so carry on.
        _ = Shell.run(brew, ["update", "--quiet"], env: env, timeout: 120)

        var outdatedEnv = env
        outdatedEnv["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        guard let result = Shell.run(brew, ["outdated", "--json=v2"], env: outdatedEnv, timeout: 60) else {
            return .failure(.failed("Couldn't run brew."))
        }
        guard let data = result.stdout.data(using: .utf8),
              let json = try? JSONDecoder().decode(OutdatedJSON.self, from: data) else {
            let message = result.stderr.split(separator: "\n").last.map(String.init) ?? "brew outdated failed."
            return .failure(.failed(message))
        }
        return .success(BrewResult(formulae: json.formulae.map(\.package), casks: json.casks.map(\.package)))
    }

    private struct OutdatedJSON: Decodable {
        let formulae: [Entry]
        let casks: [Entry]
    }

    private struct Entry: Decodable {
        let name: String
        let installedVersions: [String]
        let currentVersion: String

        enum CodingKeys: String, CodingKey {
            case name, installedVersions = "installed_versions", currentVersion = "current_version"
        }

        // Casks have reported installed_versions as a string in some brew versions.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            currentVersion = try c.decode(String.self, forKey: .currentVersion)
            if let list = try? c.decode([String].self, forKey: .installedVersions) {
                installedVersions = list
            } else {
                installedVersions = [try c.decode(String.self, forKey: .installedVersions)]
            }
        }

        var package: OutdatedPackage {
            OutdatedPackage(name: name, installed: installedVersions.last ?? "?", latest: currentVersion)
        }
    }
}
