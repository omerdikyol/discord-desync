import Cocoa
import Network
import WebKit

let appName = "Discord Desync"
let discordDataStoreID = UUID(uuidString: "8D71D487-36B4-4C08-96D9-9C23A7B8D6E1")!

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var settingsWindowController: SettingsWindowController?
    private let proxyStatusLabel = NSTextField(labelWithString: "")
    private let pageStatusLabel = NSTextField(labelWithString: "")
    private let proxyController = ProxyController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        openMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Settings.shared.stopProxyOnQuit {
            _ = try? proxyController.runSynchronously("stop-check")
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        menu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        menu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Reload Discord", action: #selector(reloadDiscord), keyEquivalent: "r"))
        viewMenuItem.submenu = viewMenu
        menu.addItem(viewMenuItem)

        let proxyMenuItem = NSMenuItem()
        let proxyMenu = NSMenu(title: "Proxy")
        proxyMenu.addItem(NSMenuItem(title: "Start Proxy", action: #selector(startProxy), keyEquivalent: ""))
        proxyMenu.addItem(NSMenuItem(title: "Restart Proxy", action: #selector(restartProxy), keyEquivalent: ""))
        proxyMenu.addItem(NSMenuItem(title: "Stop Proxy", action: #selector(stopProxy), keyEquivalent: ""))
        proxyMenu.addItem(.separator())
        proxyMenu.addItem(NSMenuItem(title: "Show Status...", action: #selector(showProxyStatus), keyEquivalent: "i"))
        proxyMenuItem.submenu = proxyMenu
        menu.addItem(proxyMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        menu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = menu
    }

    private func openMainWindow() {
        guard #available(macOS 14.0, *) else {
            showFatalError("This app needs macOS 14 or newer for per-webview proxy support.")
            return
        }

        let configuration = WKWebViewConfiguration()
        let dataStore = WKWebsiteDataStore(forIdentifier: discordDataStoreID)
        configureProxy(on: dataStore)
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
        window.contentView = makeContentView(webView: webView)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        if Settings.shared.startProxyOnLaunch {
            runProxyCommand("proxy-start", successMessage: "Proxy connected", reload: true)
        } else {
            updateProxyStatus("Proxy auto-start off", color: .secondaryLabelColor)
            loadDiscord()
        }
    }

    private func makeContentView(webView: WKWebView) -> NSView {
        let contentView = NSView()
        let statusBar = NSView()
        let separator = NSBox()
        let reloadButton = NSButton(title: "Reload", target: self, action: #selector(reloadDiscord))
        let restartButton = NSButton(title: "Restart Proxy", target: self, action: #selector(restartProxy))

        proxyStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        pageStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        pageStatusLabel.textColor = .secondaryLabelColor
        pageStatusLabel.lineBreakMode = .byTruncatingTail

        for view in [webView, statusBar, separator, proxyStatusLabel, pageStatusLabel, reloadButton, restartButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        separator.boxType = .separator

        contentView.addSubview(webView)
        contentView.addSubview(separator)
        contentView.addSubview(statusBar)
        statusBar.addSubview(proxyStatusLabel)
        statusBar.addSubview(pageStatusLabel)
        statusBar.addSubview(reloadButton)
        statusBar.addSubview(restartButton)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: separator.topAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 38),
            proxyStatusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 12),
            proxyStatusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            pageStatusLabel.leadingAnchor.constraint(equalTo: proxyStatusLabel.trailingAnchor, constant: 14),
            pageStatusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            pageStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: reloadButton.leadingAnchor, constant: -12),
            reloadButton.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            restartButton.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 8),
            restartButton.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -10),
            restartButton.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])

        return contentView
    }

    private func loadDiscord() {
        guard let url = URL(string: Settings.shared.discordURL), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            showNonFatalError("Invalid Discord URL in settings.")
            return
        }
        pageStatusLabel.stringValue = "Loading Discord..."
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
        updateProxyStatus("Checking...", color: .systemOrange)
        proxyController.run("status") { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let status):
                let isStopped = status.hasPrefix("stopped:")
                self.updateProxyStatus(isStopped ? "Proxy stopped" : "Proxy connected", color: isStopped ? .secondaryLabelColor : .systemGreen)
                self.showNonFatalInfo(status)
            case .failure(let error):
                self.updateProxyStatus("Proxy unavailable", color: .systemRed)
                self.showNonFatalError(error.localizedDescription)
            }
        }
    }

    @objc private func startProxy() {
        runProxyCommand("proxy-start", successMessage: "Proxy connected", reload: true)
    }

    @objc private func restartProxy() {
        runProxyCommand("restart", successMessage: "Proxy restarted", reload: true)
    }

    @objc private func stopProxy() {
        runProxyCommand("stop-check", successMessage: "Proxy stopped", reload: false, successColor: .secondaryLabelColor)
    }

    private func runProxyCommand(_ command: String, successMessage: String, reload: Bool, successColor: NSColor = .systemGreen) {
        updateProxyStatus("Working...", color: .systemOrange)
        proxyController.run(command) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.updateProxyStatus(successMessage, color: successColor)
                if reload { self.loadDiscord() }
            case .failure(let error):
                self.updateProxyStatus("Proxy unavailable", color: .systemRed)
                self.showNonFatalError(error.localizedDescription)
            }
        }
    }

    private func restartProxyAndReload() {
        if let dataStore = webView?.configuration.websiteDataStore {
            configureProxy(on: dataStore)
        }
        runProxyCommand("restart", successMessage: "Proxy restarted", reload: true)
    }

    private func configureProxy(on dataStore: WKWebsiteDataStore) {
        let port = NWEndpoint.Port(rawValue: UInt16(Settings.shared.port)) ?? 1080
        let endpoint = NWEndpoint.hostPort(host: .name("127.0.0.1", nil), port: port)
        dataStore.proxyConfigurations = [ProxyConfiguration(socksv5Proxy: endpoint)]
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        pageStatusLabel.stringValue = "Loading Discord..."
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageStatusLabel.stringValue = "Discord ready"
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let host = origin.host.lowercased()
        let isDiscord = host == "discord.com" || host.hasSuffix(".discord.com")
        decisionHandler(Settings.shared.grantDiscordMediaPermission && isDiscord ? .grant : .prompt)
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        pageStatusLabel.stringValue = "Discord failed to load"
        showNonFatalError("Page load failed:\n\n\(error.localizedDescription)")
    }

    private func updateProxyStatus(_ text: String, color: NSColor) {
        proxyStatusLabel.stringValue = "●  \(text)"
        proxyStatusLabel.textColor = color
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
