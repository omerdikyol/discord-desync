import Cocoa
import Network
import WebKit

private let appName = "Discord Desync"
private let discordDataStoreID = UUID(uuidString: "8D71D487-36B4-4C08-96D9-9C23A7B8D6E1")!

private enum Strategy: String, CaseIterable {
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

private final class Settings {
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

private final class SettingsWindowController: NSWindowController {
    private let discordURLField = NSTextField()
    private let healthURLField = NSTextField()
    private let portField = NSTextField()
    private let strategyPopup = NSPopUpButton()
    private let customFlagsField = NSTextField()
    private let startProxyCheckbox = NSButton(checkboxWithTitle: "Start ByeDPI when Discord Desync opens", target: nil, action: nil)
    private let stopProxyCheckbox = NSButton(checkboxWithTitle: "Stop ByeDPI when Discord Desync quits", target: nil, action: nil)
    private let mediaPermissionCheckbox = NSButton(checkboxWithTitle: "Remember Discord microphone/camera permission inside the app", target: nil, action: nil)
    private let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(appName) Settings"
        super.init(window: window)
        buildContent()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for item in Strategy.allCases {
            strategyPopup.addItem(withTitle: item.title)
        }

        stack.addArrangedSubview(row("Discord URL", discordURLField))
        stack.addArrangedSubview(row("Health Check URL", healthURLField))
        stack.addArrangedSubview(row("SOCKS Port", portField))
        stack.addArrangedSubview(row("Strategy", strategyPopup))
        stack.addArrangedSubview(row("Custom Flags", customFlagsField))
        stack.addArrangedSubview(startProxyCheckbox)
        stack.addArrangedSubview(stopProxyCheckbox)
        stack.addArrangedSubview(mediaPermissionCheckbox)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let saveButton = NSButton(title: "Save & Restart", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        buttons.addArrangedSubview(spacer)
        buttons.addArrangedSubview(cancelButton)
        buttons.addArrangedSubview(saveButton)
        stack.addArrangedSubview(buttons)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func row(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 130).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        return row
    }

    private func loadSettings() {
        let settings = Settings.shared
        discordURLField.stringValue = settings.discordURL
        healthURLField.stringValue = settings.healthURL
        portField.stringValue = String(settings.port)
        strategyPopup.selectItem(withTitle: settings.strategy.title)
        customFlagsField.stringValue = settings.customFlags
        startProxyCheckbox.state = settings.startProxyOnLaunch ? .on : .off
        stopProxyCheckbox.state = settings.stopProxyOnQuit ? .on : .off
        mediaPermissionCheckbox.state = settings.grantDiscordMediaPermission ? .on : .off
    }

    @objc private func cancel() {
        close()
    }

    @objc private func save() {
        let settings = Settings.shared
        settings.discordURL = discordURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.healthURL = healthURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.port = Int(portField.stringValue) ?? 1080
        settings.strategy = Strategy.allCases[strategyPopup.indexOfSelectedItem]
        settings.customFlags = customFlagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.startProxyOnLaunch = startProxyCheckbox.state == .on
        settings.stopProxyOnQuit = stopProxyCheckbox.state == .on
        settings.grantDiscordMediaPermission = mediaPermissionCheckbox.state == .on
        close()
        onSave()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var settingsWindowController: SettingsWindowController?
    private var controllerScript: String {
        Bundle.main.path(forResource: "discord-desync-proxy", ofType: "sh") ?? "\(FileManager.default.currentDirectoryPath)/Resources/discord-desync-proxy.sh"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        openMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Settings.shared.stopProxyOnQuit {
            _ = try? runController("stop-check")
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem(title: "Reload Discord", action: #selector(reloadDiscord), keyEquivalent: "r"))
        appMenu.addItem(NSMenuItem(title: "Proxy Status", action: #selector(showProxyStatus), keyEquivalent: "i"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        menu.addItem(appMenuItem)
        NSApp.mainMenu = menu
    }

    private func openMainWindow() {
        guard #available(macOS 14.0, *) else {
            showFatalError("This app needs macOS 14 or newer for per-webview proxy support.")
            return
        }

        if Settings.shared.startProxyOnLaunch {
            do {
                _ = try runController("proxy-start")
            } catch {
                showFatalError("Could not start ByeDPI:\n\n\(error.localizedDescription)")
                return
            }
        }

        let configuration = WKWebViewConfiguration()
        let dataStore = WKWebsiteDataStore(forIdentifier: discordDataStoreID)
        let port = NWEndpoint.Port(rawValue: UInt16(Settings.shared.port)) ?? 1080
        let proxyEndpoint = NWEndpoint.hostPort(host: .name("127.0.0.1", nil), port: port)
        dataStore.proxyConfigurations = [ProxyConfiguration(socksv5Proxy: proxyEndpoint)]
        configuration.websiteDataStore = dataStore
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        window.center()
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        loadDiscord()
    }

    private func loadDiscord() {
        guard let url = URL(string: Settings.shared.discordURL) else {
            showNonFatalError("Invalid Discord URL in settings.")
            return
        }
        webView?.load(URLRequest(url: url))
    }

    @objc private func reloadDiscord() {
        loadDiscord()
    }

    @objc private func openSettings() {
        let controller = SettingsWindowController { [weak self] in
            self?.restartProxyAndReload()
        }
        settingsWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showProxyStatus() {
        do {
            showNonFatalInfo(try runController("status"))
        } catch {
            showNonFatalError(error.localizedDescription)
        }
    }

    private func restartProxyAndReload() {
        guard Settings.shared.startProxyOnLaunch else {
            loadDiscord()
            return
        }
        do {
            _ = try runController("restart")
            loadDiscord()
        } catch {
            showNonFatalError("Could not restart ByeDPI:\n\n\(error.localizedDescription)")
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showNonFatalError("Page load failed:\n\n\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showNonFatalError("Page load failed:\n\n\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(Settings.shared.grantDiscordMediaPermission ? .grant : .prompt)
    }

    private func runController(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [controllerScript, command]
        process.environment = ProcessInfo.processInfo.environment.merging(proxyEnvironment()) { _, new in new }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(domain: appName, code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "Command failed: \(command)" : text])
        }
        return text
    }

    private func proxyEnvironment() -> [String: String] {
        let settings = Settings.shared
        return [
            "DISCORD_DESYNC_PORT": String(settings.port),
            "DISCORD_DESYNC_FLAGS": settings.strategy.flags,
            "DISCORD_DESYNC_HEALTH_URL": settings.healthURL
        ]
    }

    private func showFatalError(_ message: String) {
        showNonFatalError(message)
        NSApp.terminate(nil)
    }

    private func showNonFatalError(_ message: String) {
        showAlert(message, style: .warning)
    }

    private func showNonFatalInfo(_ message: String) {
        showAlert(message, style: .informational)
    }

    private func showAlert(_ message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = appName
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
