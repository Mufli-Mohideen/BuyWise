//
//  BuyWiseApp.swift
//  BuyWise
//
//  Created by Mufli Mohideen on 2026-09-23.
//

import SwiftUI

@main
struct BuyWiseApp: App {
    @StateObject private var appState = AppState()

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
        }
    }
}
