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
    
    var viewModel = GlobalSettingsViewModel()
    
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
            currentWallpaper = wallpaper
            AppDelegate.shared.saveCurrentWallpaper()
            AppDelegate.shared.setPlacehoderWallpaper(with: wallpaper)
            UserDefaults.standard.set(try! JSONEncoder().encode(currentWallpaper), forKey: "CurrentWallpaper")
        } else {
            currentWallpaper = WEWallpaper(using: .invalid, where: Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!)
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        print("replaying...")
        let playList = UserDefaults.standard.string(forKey: "PlayList")?.split(separator: "|").compactMap{ "\($0)" }
        if (playList == nil) == false {
            if viewModel.settings.EnablePlaylist == true {
                if playList!.count > 1 {
                    if UserDefaults.standard.object(forKey: "SwitchWallpaperTiming") != nil {
                        if viewModel.settings.hourText == "0" && viewModel.settings.minuteText == "0" {
                            print("切换壁纸时间错误，取消切换");
                        }
                        else {
                            let switchTiming = UserDefaults.standard.double(forKey: "SwitchWallpaperTiming")
                            let timeInterval = Date().timeIntervalSince1970
                            if timeInterval > switchTiming {
                                print("模式: ", viewModel.settings.playOrder)
                                let wallpaperName = self.currentWallpaper.wallpaperDirectory.absoluteString.split(separator: "/").compactMap({ "\($0)" }).last!
                                if viewModel.settings.playOrder == "Random" {
                                    var isSame = true
                                    var randomIndex = 0
                                    while isSame {
                                        randomIndex = Int.random(in: 0...((playList?.count ?? 0) - 1))
                                        if playList![randomIndex] == wallpaperName {
                                            print("壁纸相同，重新随机")
                                        }
                                        else {
                                            isSame = false
                                        }
                                    }
                                    print("随机壁纸: ", playList![randomIndex].removingPercentEncoding ?? "", "\n序号: ", randomIndex)
                                    setWallpaper(wallpaperName: playList![randomIndex])
                                }
                                else {
                                    @State var nextWallpaperIndex = -1
                                    let index = 0
                                    for name in wallpaperName {
                                        if(String(name) == playList![index]) {
                                            if(index != (playList!.count - 1)){
                                                nextWallpaperIndex = index + 1
                                            }
                                            else {
                                                nextWallpaperIndex = 0
                                            }
                                        }
                                    }
                                    print("下一个壁纸: ", playList![nextWallpaperIndex].removingPercentEncoding ?? "", "序号: ", nextWallpaperIndex)
                                    if nextWallpaperIndex != -1 {
                                        setWallpaper(wallpaperName: playList![nextWallpaperIndex])
                                    }
                                }
                            } else {
                                print("切换时间戳: ", switchTiming, "当前时间戳:  ", timeInterval)
                                print("播放列表数量: ", playList?.count)
                            }
                        }
                    }
                } else {
                    print("播放列表壁纸过少，取消切换")
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
