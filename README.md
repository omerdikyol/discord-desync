# Discord Desync

A macOS app that opens Discord in WebKit and manages a local ByeDPI SOCKS5 proxy for that embedded view. Proxy lifecycle and settings are handled inside the app.

It avoids changing macOS firewall or system proxy settings, and it avoids the Chrome flag/profile problems that happen when trying to launch Discord through a proxied browser window.

## Features

- Native macOS app window for `https://discord.com/app`
- Per-app WebKit SOCKS5 proxy using `127.0.0.1`
- Bundled ByeDPI backend
- Starts ByeDPI when the app opens
- Stops ByeDPI when the app quits
- Shows live proxy and page-loading status in the app window
- Provides direct start, restart, stop, and status controls from the Proxy menu
- Includes standard macOS editing shortcuts for Discord messages
- Built-in Settings window:
  - Discord URL
  - health-check URL
  - SOCKS port
  - ByeDPI strategy preset
  - custom ByeDPI flags
  - media permission behavior
- Ad-hoc signed local build with a stable bundle identifier
- Restricts automatic microphone and camera permission to Discord domains

## Requirements

- macOS 14 or newer
- Xcode Command Line Tools

Install tools once:

```bash
xcode-select --install
```

## Build

```bash
git submodule update --init --recursive
scripts/build.sh
```

The app is created at:

```text
build/Discord Desync.app
```

## Install

```bash
scripts/build.sh --install
```

This installs:

```text
/Applications/Discord Desync.app
```

You can then open it from Applications, Spotlight, Launchpad, or the Dock.

## Settings

Open `Discord Desync > Settings...`.

The default strategy is:

```text
--disorder 1 --auto=torst --tlsrec 1+s
```

If your network needs a different ByeDPI mode, choose another preset or use `Custom`.

## Runtime Files

Runtime state is stored in:

```text
~/Library/Application Support/Discord Desync
```

This includes the ByeDPI PID file and log.

Discord login/cookies are stored in WebKit's persistent data store for the app bundle identifier:

```text
~/Library/WebKit/com.omerdikyol.discorddesync
```

If macOS asks for microphone or camera permission after reinstalling, grant it once. The app also grants Discord's in-page media permission automatically when the setting is enabled.

## Dependency

Discord Desync embeds [`hufrea/byedpi`](https://github.com/hufrea/byedpi), which is MIT licensed.

## Notes

Discord Desync is not affiliated with Discord or ByeDPI. It is a local convenience wrapper around WebKit and ByeDPI.

## Reading the implementation

Start with [the AppKit entry point](Sources/DiscordDesync/main.swift), then [ProxyController](Sources/DiscordDesync/ProxyController.swift) for the process queue and [Settings](Sources/DiscordDesync/Settings.swift) for persisted options. [scripts/test.sh](scripts/test.sh) checks the local build and proxy setup; read it before running because it starts processes and inspects local runtime state.

## Architecture

- `main.swift` owns the AppKit lifecycle and WebKit presentation.
- `ProxyController.swift` serializes ByeDPI operations on a background queue so health checks and restarts do not freeze the UI.
- `Settings.swift` owns persisted configuration and strategy presets.
- `SettingsWindowController.swift` owns settings presentation and editing.
- `discord-desync-proxy.sh` owns process discovery, lifecycle, and health checks.
