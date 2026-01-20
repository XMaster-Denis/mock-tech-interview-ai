//
//  XInterview2App.swift
//  XInterview2
//
//  Main app entry point
//

import SwiftUI

@main
struct XInterview2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("menu.settings") {
                    // Settings will be opened via sheet in MainView
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
