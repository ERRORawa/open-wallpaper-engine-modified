//
//  VideoWallpaperViewModel.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/14.
//

import AVKit
import SwiftUI

class VideoWallpaperViewModel: ObservableObject {
    var currentWallpaper: WEWallpaper {
        willSet {
            self.player.replaceCurrentItem(with: AVPlayerItem(url: newValue.wallpaperDirectory.appending(path: newValue.project.file)))
        }
    }
    
    
    var playRate: Float = 0 {
        willSet {
            self.player.rate = newValue
        }
    }
    
    var playVolume: Float = 0 {
        willSet {
            self.player.volume = newValue
        }
    }
    
    var player = AVPlayer()
    
    init(wallpaper currentWallpaper: WEWallpaper) {
        self.currentWallpaper = currentWallpaper
        self.player = AVPlayer(url: currentWallpaper.wallpaperDirectory.appending(path: currentWallpaper.project.file))
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep(_:)), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setWallpaper(wallpaperName: String) {
        if let json = UserDefaults.standard.data(forKey: wallpaperName),
           let wallpaper = try? JSONDecoder().decode(WEWallpaper.self, from: json) {
            AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = wallpaper
        } else {
            AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = WEWallpaper(using: .invalid, where: Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!)
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        print("replaying...")
        if AppDelegate.shared.viewModel.settings.switchAfterFinish {
            let viewModel = AppDelegate.shared.viewModel
            let playList = UserDefaults.standard.string(forKey: "PlayList")?.split(separator: "|").compactMap{ "\($0)" }
            if !(playList == nil) {
                if viewModel.settings.EnablePlaylist {
                    if playList!.count > 1 {
                        if UserDefaults.standard.object(forKey: "SwitchWallpaperTiming") != nil {
                            if viewModel.settings.hourText == "0" && viewModel.settings.minuteText == "0" {
                                print("切换壁纸时间错误，取消切换");
                            }
                            else {
                                let switchTiming = UserDefaults.standard.double(forKey: "SwitchWallpaperTiming")
                                let timeInterval = Date().timeIntervalSince1970
                                if timeInterval > switchTiming {
                                    AppDelegate.shared.switchPlayList()
                                } else {
                                    print("切换时间戳: ", switchTiming, "当前时间戳:  ", timeInterval)
                                    print("播放列表数量: ", playList!.count)
                                }
                            }
                        }
                    } else {
                        print("播放列表壁纸过少，取消切换")
                    }
                }
            }
        }
        // 重新播放视频
        self.player.seek(to: CMTime.zero)
        self.player.rate = self.playRate
    }
    
    @objc private func playerDidStopPlaying(_ notification: Notification) {
        print("stopped, trying to resume...")
        // 重新播放视频
        self.player.rate = self.playRate
    }
    
    @objc func systemWillSleep(_ notification: Notification) {
        // Handle going to sleep
        print("System is going to sleep")
        // Update your SwiftUI state here if needed
        self.player.rate = self.playRate
    }
        
    @objc func systemDidWake(_ notification: Notification) {
        // Handle waking up
        print("System woke up from sleep")
        // Update your SwiftUI state here if needed
        self.player.rate = self.playRate
    }
}
