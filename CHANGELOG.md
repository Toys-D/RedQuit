# Changelog

## Unreleased

- README: building from source requires Xcode 16 or newer (Swift 6), not Xcode 15.

## 1.0.0 — 2026-11-07

The first public release.

- The red close button quits the app when it closes the app's last window (**Last window** mode), or whenever it closes any window (**Any window** mode).
- Reacts only to a mouse click on the red button; ⌘W and File ▸ Close are left alone.
- Waits until the window really closes: pressing Cancel in a "Save changes?" dialog keeps the app running.
- Quits apps the normal way, like ⌘Q; never force-quits.
- Counts minimized windows, windows on other desktops and full-screen windows as open.
- Works with quick clicks and trackpad taps.
- Leaves Finder, system processes and background apps alone; your own exclusion list.
- Menu bar icon with Pause, Mode and Settings; Open at login.
- 16 languages: English, Русский, Українська, Español, Português (Brasil), Français, Deutsch, Italiano, Polski, Türkçe, 日本語, 한국어, 简体中文, 繁體中文, العربية, हिन्दी.
- Universal app for Apple Silicon and Intel, macOS 14 Sonoma or newer.
