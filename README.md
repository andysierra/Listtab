<p align="center"><img src="macos%20version/images/icon.png" width="128" alt="ListTab icon"></p>

# ListTab

**A window switcher that shows a list: icon · full title · app.** Most recent window first, tracked
per window (not per app), close windows from the list, rows shrink so every window fits without scrolling.

Two native versions, same UI and same behavior:

| | Version | Shortcut | Stack | Docs |
|---|---|---|---|---|
| 🍎 | [**macos version/**](macos%20version/) | ⌘Tab | Swift, AppKit + SwiftUI, Accessibility API | [README](macos%20version/README.md) |
| 🐧 | [**linux mate version/**](linux%20mate%20version/) | Alt+Tab | Python 3, GTK 3 + cairo, libwnck, X11 | [README](linux%20mate%20version/README.md) |

<p align="center">
  <img src="macos%20version/images/panel.png" width="49%" alt="ListTab on macOS">
  <img src="linux%20mate%20version/images/panel.png" width="49%" alt="ListTab on Linux MATE">
</p>
<p align="center"><sub>macOS (left) · Linux Mint MATE (right)</sub></p>

## Quick start

```bash
# macOS (needs Xcode)
cd "macos version" && ./build.sh install

# Linux Mint MATE (X11; no sudo, nothing to compile)
cd "linux mate version" && ./install.sh && listtab
```

The only behavioral difference: on macOS **⌥-click** on a row's ✕ quits the app; on Linux Alt is the key you
hold while switching, so it is **Shift-click**. Linux also lets you list windows of **all workspaces** (default)
or only the current one, and **click a row** to jump to it.

## License

[MIT](LICENSE).
