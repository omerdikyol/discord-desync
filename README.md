# Discord Desync

Discord Desync is a small macOS Discord web app that starts a local ByeDPI SOCKS5 proxy and routes only its embedded WebKit view through that proxy.

It avoids changing macOS firewall or system proxy settings, and it avoids the Chrome flag/profile problems that happen when trying to launch Discord through a proxied browser window.

## Features

- Native macOS app window for `https://discord.com/app`
- Per-app WebKit SOCKS5 proxy using `127.0.0.1`
- Bundled ByeDPI backend
- Starts ByeDPI when the app opens
- Stops ByeDPI when the app quits
- Built-in Settings window:
  - Discord URL
  - health-check URL
  - SOCKS port
  - ByeDPI strategy preset
  - custom ByeDPI flags
  - media permission behavior
- Ad-hoc signed local build with a stable bundle identifier

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
