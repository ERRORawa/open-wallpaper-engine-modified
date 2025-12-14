//
//  AppState.swift
//  Open Wallpaper Engine Modified
//
//  Created by ERROR on 2025/12/14.
//

import SwiftUI

final class AppState: ObservableObject {
    
    @Published var localeIdentifier: String = "en-US"
    
    init() {
        var id = Locale.current.identifier;
        if let identifier = UserDefaults.standard.string(forKey: "locale_identifier") {
            if identifier != "system" {
                id = identifier
            }
        }
        if id.hasPrefix("zh") {
            _localeIdentifier = Published(initialValue: "zh-CN")
        }
    }
}
