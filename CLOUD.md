# CLOUD.md

## Cursor Cloud specific instructions

### Cloud Agent harness rules (local, not committed)

The environment setup (update script) generates an **untracked** `CLOUD.harness.md` at the
repo root on VM startup. It holds fork-specific PR/upstream guidance for this repository and
is intentionally kept out of git (registered in `.git/info/exclude`, so it never appears in
`git status` or commits). **Before starting work or opening a PR, read `CLOUD.harness.md`
if it is present** and follow its rules. Do not commit it or add it to tracked git ignore
files.

### Platform requirement: this is a macOS/Xcode-only iOS app

Go Map!! is a native **iOS/iPadOS** application (Swift 5 + Objective-C, UIKit). Building,
running, and testing it require **macOS with Xcode** — there is no server, web, or
otherwise cross-platform component in this repository.

The Cursor Cloud Agent VM runs **Linux (Ubuntu x86_64)**, so the app **cannot be built,
run, or tested here**. This is a hard platform limitation, not a missing dependency:

- The build/test toolchain is `xcodebuild` + the iOS Simulator, which are macOS-only.
  CI runs on `macos-latest` with Xcode `>= 26.3` (see `.github/workflows/ci.yml`).
- Tests are `GoMapTests` / `GoMapUITests`, run via
  `xcodebuild test -scheme GoMapTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
  (also wrapped by `bundle exec fastlane ios pull_request_checks`, see `src/iOS/fastlane/Fastfile`).
- UIKit and the iOS SDKs are Apple-proprietary and unavailable on Linux; the open-source
  Swift-for-Linux toolchain cannot compile this code even if installed.
- Even the vendored formatter `vendor/clang-format` is a Mach-O (macOS) binary and will
  not execute on Linux.

**Implication for future cloud agents:** do not attempt to install a Linux toolchain to
build/run/test this app — it will not work. Code changes here must be built and tested on
a macOS machine with Xcode (open `src/iOS/Go Map!!.xcodeproj`), or via the macOS GitHub
Actions CI. There is no meaningful "run the app" step available in this Linux VM.

### Where things live

- Xcode project: `src/iOS/Go Map!!.xcodeproj` (schemes: `Go Map!!`, `GoMapTests`, `GoMapUITests`).
- Fastlane lanes: `src/iOS/fastlane/Fastfile` (`pull_request_checks`, `beta`, etc.).
- Formatting: SwiftFormat (`.swiftformat`) and clang-format (`.clang-format`) — see `README.md`.
- Asset-update scripts (Python/shell) live under `src/presets`, `src/POI-Icons`, `src/xliff`;
  these update bundled data and are not part of building/running the app.
