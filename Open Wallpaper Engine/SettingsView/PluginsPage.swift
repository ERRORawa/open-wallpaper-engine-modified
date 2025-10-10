//
//  PluginsPage.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/12.
//

import SwiftUI

struct PluginsPage: SettingsPage {
    @ObservedObject var viewModel: GlobalSettingsViewModel
    
    let hours = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]
    let minutes = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59]
    
    
    init(globalSettings viewModel: GlobalSettingsViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Form {
            // MARK: Enable Playlist
            Section {
                Toggle("Enabled", isOn: $viewModel.settings.EnablePlaylist)
            } header: {
                Label("Enable Playlist", systemImage: "star.fill")
            }
            // MARK: Switch Time
            Section {
                Picker("Hour", selection: $viewModel.settings.hourText) {
                    ForEach(hours, id: \.self) { hour in
                        Text(String(hour)).tag(String(hour))
                    }
                }
                Picker("Minute", selection: $viewModel.settings.minuteText) {
                    ForEach(minutes, id: \.self) { minute in
                        Text(String(minute)).tag(String(minute))
                    }
                }
            } header: {
                Label("Switch Time", systemImage: "gearshape.fill")
            }
            // MARK: Play Order
            Section {
                Picker("Play Order", selection: $viewModel.settings.playOrder) {
                    Text("Random").tag("Random")
                    Text("Order").tag("Order")
                }
            } header: {
                Label("Playlist Order", systemImage: "film")
            }
            // MARK: Other
            Section {
                Toggle("Switch after video finish", isOn: $viewModel.settings.switchAfterFinish)
                    .disabled(true)
                Toggle("Always start at first wallpaper", isOn: $viewModel.settings.alwaysFirst)
                    .disabled(true)
            } header: {
                Label("Other", systemImage: "wrench.and.screwdriver.fill")
            }
        }.formStyle(.grouped)
    }
}
