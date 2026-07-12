import Foundation

enum Strategy: String, CaseIterable {
    case balanced
    case conservative
    case aggressive
    case custom

    var title: String {
        switch self {
        case .balanced: return "Balanced"
        case .conservative: return "Conservative"
        case .aggressive: return "Aggressive"
        case .custom: return "Custom"
        }
    }

    var flags: String {
        switch self {
        case .balanced:
            return "--disorder 1 --auto=torst --tlsrec 1+s"
        case .conservative:
            return "--auto=torst --tlsrec 1+s"
        case .aggressive:
            return "--disorder 1 --auto=torst --tlsrec 1+s --split 1+s"
        case .custom:
            return Settings.shared.customFlags
        }
    }
}

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    var discordURL: String {
        get { defaults.string(forKey: "discordURL") ?? "https://discord.com/app" }
        set { defaults.set(newValue, forKey: "discordURL") }
    }

    var healthURL: String {
        get { defaults.string(forKey: "healthURL") ?? "https://discord.com" }
        set { defaults.set(newValue, forKey: "healthURL") }
    }

    var port: Int {
        get {
            let value = defaults.integer(forKey: "port")
            return value > 0 ? value : 1080
        }
        set { defaults.set(max(1, min(newValue, 65535)), forKey: "port") }
    }

    var strategy: Strategy {
        get { Strategy(rawValue: defaults.string(forKey: "strategy") ?? "") ?? .balanced }
        set { defaults.set(newValue.rawValue, forKey: "strategy") }
    }

    var customFlags: String {
        get { defaults.string(forKey: "customFlags") ?? "--disorder 1 --auto=torst --tlsrec 1+s" }
        set { defaults.set(newValue, forKey: "customFlags") }
    }

    var startProxyOnLaunch: Bool {
        get { defaults.object(forKey: "startProxyOnLaunch") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "startProxyOnLaunch") }
    }

    var stopProxyOnQuit: Bool {
        get { defaults.object(forKey: "stopProxyOnQuit") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "stopProxyOnQuit") }
    }

    var grantDiscordMediaPermission: Bool {
        get { defaults.object(forKey: "grantDiscordMediaPermission") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "grantDiscordMediaPermission") }
    }
}
