//
//  AppState.swift
//  Open Wallpaper Engine Modified
//
//  Created by ERROR on 2025/12/14.
//

import SwiftUI

final class LanguageState: ObservableObject {
    
    var localeIdentifier: String = "en-US"
    
    init() {
        localeIdentifier = Locale.current.identifier;
        if let identifier = UserDefaults.standard.string(forKey: "locale_identifier") {
            localeIdentifier = identifier
        }
    }
    
    func setLanguage(code: String) {
        if code == localeIdentifier {
            return
        }
        if code == "system" {
            localeIdentifier = Locale.current.identifier
            UserDefaults.standard.removeObject(forKey: "locale_identifier")
        } else {
            localeIdentifier = code
            UserDefaults.standard.set(code, forKey: "locale_identifier")
        }
    }
}
