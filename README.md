# ClearSpace

A native macOS app that shows what is filling your disk and helps you reclaim the space safely. Built with SwiftUI for developers whose Macs fill up with build products, emulator images and package caches.

![Build](https://github.com/UmairSharif/ClearSpace/actions/workflows/build.yml/badge.svg)

## Download

Get the latest **ClearSpace .dmg** from [Releases](https://github.com/UmairSharif/ClearSpace/releases/latest), open it and drag ClearSpace into Applications. It needs macOS 14 Sonoma or later and runs natively on Apple silicon and Intel. Each release also has the source code as a .zip and .tar.gz.

The app is not notarized by Apple yet, so macOS blocks it the first time you open it. Click **Done**, then go to **System Settings > Privacy & Security** and click **Open Anyway** next to ClearSpace. You only need to do this once per version.

## Features

- **Overview**: disk usage at a glance, with the reclaimable share highlighted.
- **Smart Clean**: a curated scan of known space hogs, grouped by category.
  - Xcode: Derived Data, device support files, simulator caches, Swift package cache, archives
  - Android: emulator system images, virtual devices, Gradle caches and wrapper distributions
  - Package managers: npm, Yarn, pnpm, CocoaPods, Dart pub, Homebrew, uv, pip, Cargo, NuGet, Go, Playwright
  - App caches, logs and the Trash
  - Docker and simulator disk images, shown with the command that cleans them properly
- **Large Files**: find the biggest files in any folder, sort them, and reveal them in Finder.
- **Project Junk**: find `node_modules`, `Pods`, `build`, `.dart_tool`, `DerivedData`, `target` and similar folders across your projects. Source code is never touched.
- **Malware Check**: find hidden malware aimed at developers in your projects, such as VS Code tasks that run when a folder is opened, scripts disguised as fonts or images, obfuscated or off-screen code, and leftovers on your Mac. Every finding says why it was flagged, nothing is run, and removal goes through the same confirmation and Trash. See [docs/hidden-malware.md](docs/hidden-malware.md) for the cleanup guide.

## Safety model

Deleting files is the one thing this app must never get wrong, so every removal goes through the same pipeline:

1. **Analyze first.** Scans only read sizes. Nothing changes on disk.
2. **Every item is labelled.**
   - `Safe`: rebuilt automatically by the tool that owns it.
   - `Review`: may not come back on its own, such as Xcode archives or emulator devices.
   - `Manual`: shown for awareness only and cleaned with the owning tool, such as Docker.
3. **You confirm.** A sheet lists exactly what will be removed and its total size.
4. **Trash by default.** Items move to the Trash so you can restore them. Permanent deletion is an explicit choice.
5. **Guard rails.** `SafetyGuard` refuses to remove protected locations such as `~/Documents`, `~/Library` or anything outside your home folder, even if a scan produced a bad path.
6. **Honest results.** The summary lists anything that could not be removed and why.

## Permissions

ClearSpace asks for access on first launch and explains why before macOS shows its prompts.

| Permission | Why | How it is granted |
|---|---|---|
| Files and Folders | Measure Desktop, Documents and Downloads | macOS prompts when you click **Allow** |
| Full Disk Access (recommended) | Measure the Trash, app containers and some caches | System Settings > Privacy & Security > Full Disk Access |

The app is not sandboxed, because a sandboxed app cannot read the cache folders it needs to measure. It makes no network requests and collects no data.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later to build

## Publishing a release

Bump `MARKETING_VERSION` in the Xcode project, merge to `main`, then run the **Release** workflow from the Actions tab (or push a tag such as `v1.0.3`). It builds a universal Release app, packages `ClearSpace-<version>.dmg` with a SHA-256 checksum, and publishes the GitHub Release. See [release.yml](.github/workflows/release.yml) for the optional Developer ID signing and notarization secrets.

## Build and run

```bash
git clone https://github.com/UmairSharif/ClearSpace.git
cd ClearSpace
open ClearSpace.xcodeproj
```

Press **Run** in Xcode. The project signs the app to run locally, so no developer team is needed.

From the command line:

```bash
xcodebuild -project ClearSpace.xcodeproj -scheme ClearSpace -configuration Release -derivedDataPath build build
open build/Build/Products/Release/ClearSpace.app
```

> macOS ties privacy permissions to the app's code signature. With local signing, a rebuilt app may need Full Disk Access granted again. Signing with your own Developer ID avoids this.

## Project structure

```
ClearSpace/
├── App/                 App entry point and shared AppModel
├── Navigation/          Router, typed Routes and NavigationModel
├── Core/
│   ├── Models/          Value types: CleanupItem, FileEntry, DeletionReport ...
│   ├── Services/        Scanners, size calculation, deletion, permissions
│   └── Utilities/       Formatting and AppKit helpers
├── DesignSystem/        Theme and reusable views
├── Features/
│   ├── Root/            Split view and sidebar
│   ├── Onboarding/      Permission walkthrough
│   ├── Dashboard/       Overview
│   ├── SmartClean/      Category list and detail
│   ├── LargeFiles/      Sortable file table
│   ├── ProjectArtifacts/Dependency and build folders
│   ├── Cleanup/         Confirmation and result sheets
│   └── Settings/
└── Resources/           Asset catalog
```

### Architecture notes

- **SwiftUI with the Observation framework.** View models are `@Observable` and `@MainActor`. File system work runs off the main thread in `nonisolated` services and honours task cancellation.
- **Navigation.** A `NavigationSplitView` sidebar where every section owns a `NavigationStack` driven by its own `Router` (`push`, `pop`, `popToRoot`). Routes are typed, and deep links set the path directly.
- **One deletion pipeline.** Features never delete anything themselves. They hand a `DeletionRequest` to `AppModel`, which presents the confirmation sheet and calls `DeletionService`.
- **Adding a cleanup location** is one entry in `CleanupCatalog.swift`.

## Extending the catalog

```swift
CleanupTarget(
    title: "Bun Cache",
    relativePath: ".bun/install/cache",
    category: .packageManagers,
    safety: .safe,
    explanation: "Downloaded packages. Fetched again on the next install."
)
```

## License

MIT. See [LICENSE](LICENSE).
