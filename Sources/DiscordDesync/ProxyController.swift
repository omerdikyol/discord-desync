import Foundation

final class ProxyController {
    private let queue = DispatchQueue(label: "com.omerdikyol.discorddesync.proxy", qos: .userInitiated)

    func run(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        let script = controllerScript
        let environment = proxyEnvironment()

        queue.async {
            let result = Result { try Self.runProcess(script: script, command: command, environment: environment) }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func runSynchronously(_ command: String) throws -> String {
        let script = controllerScript
        let environment = proxyEnvironment()
        return try queue.sync {
            try Self.runProcess(script: script, command: command, environment: environment)
        }
    }

    private var controllerScript: String {
        Bundle.main.path(forResource: "discord-desync-proxy", ofType: "sh")
            ?? "\(FileManager.default.currentDirectoryPath)/Resources/discord-desync-proxy.sh"
    }

    private func proxyEnvironment() -> [String: String] {
        let settings = Settings.shared
        return [
            "DISCORD_DESYNC_PORT": String(settings.port),
            "DISCORD_DESYNC_FLAGS": settings.strategy.flags,
            "DISCORD_DESYNC_HEALTH_URL": settings.healthURL
        ]
    }

    private static func runProcess(script: String, command: String, environment: [String: String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script, command]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(
                domain: appName,
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "Command failed: \(command)" : text]
            )
        }
        return text
    }
}
