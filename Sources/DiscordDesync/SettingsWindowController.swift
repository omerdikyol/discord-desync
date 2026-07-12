import Cocoa

final class SettingsWindowController: NSWindowController {
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
