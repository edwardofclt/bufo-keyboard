// Minimal SnapshotHelper compatible with fastlane snapshot.
//
// fastlane's official SnapshotHelper.swift has more bells and whistles
// (multi-platform, animation waiting, network-indicator handling). Once
// you've run `bundle exec fastlane snapshot init` from this repo, you can
// replace this file with the canonical one fastlane drops in.
//
// What this needs to do for fastlane to pick up screenshots:
// 1. Propagate FASTLANE_SNAPSHOT and language launch args to the app.
// 2. Take an XCUIScreen screenshot and attach it to the test with
//    lifetime .keepAlways so it survives in the .xcresult bundle.
// fastlane then extracts those attachments into PNGs.

import XCTest

func setupSnapshot(_ app: XCUIApplication) {
    Snapshot.setupSnapshot(app)
}

func snapshot(_ name: String) {
    Snapshot.snapshot(name)
}

enum Snapshot {
    static var app: XCUIApplication?

    static func setupSnapshot(_ app: XCUIApplication) {
        Snapshot.app = app
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES"]
        let env = ProcessInfo.processInfo.environment
        if let lang = env["SNAPSHOT_LANGUAGES"]?.split(separator: ",").first.map(String.init) {
            app.launchArguments += ["-AppleLanguages", "(\(lang))"]
        }
        if let locale = env["SNAPSHOT_LOCALE"] {
            app.launchArguments += ["-AppleLocale", locale]
        }
    }

    static func snapshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "snapshot_\(name)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "snapshot: \(name)") { activity in
            activity.add(attachment)
        }
    }
}
