//
//  AppDelegate.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/6/6.
//

import Cocoa
import SwiftUI
import AVKit
import AppKit
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow!
    
    var mainWindowController: MainWindowController!
    
    var wallpaperWindow: NSWindow!
    
    @Published var changePlayList = -1
    
    var contentViewModel = ContentViewModel()
    var wallpaperViewModel = WallpaperViewModel()
    
    var importOpenPanel: NSOpenPanel!
    var nsView = WKWebView(frame: .zero)
    
    @Published var webProperties:  NSMutableDictionary = [:]
    
    @Published var timer: Timer?
    
    var eventHandler: Any?
    
    static var shared = AppDelegate()
    
    var viewModel = GlobalSettingsViewModel()
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 创建设置视窗
        setSettingsWindow()
        
        // 创建桌面壁纸视窗
        setWallpaperWindow()
        
        // 创建化左上角菜单栏
        setMainMenu()
        
        // 创建化右上角常驻菜单栏
        setStatusMenu()
        
        // 创建主视窗
        self.mainWindowController = MainWindowController()
        
        // 将外部输入传递到壁纸窗口
        AppDelegate.shared.setEventHandler()
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = self.statusItem.menu?.copy() as! NSMenu?
        dockMenu?.items.removeLast() // Remove `Quit` menu item
        return dockMenu
    }
    
// MARK: - delegate methods
    func applicationDidFinishLaunching(_ notification: Notification) {
        saveCurrentWallpaper()
        AppDelegate.shared.setPlacehoderWallpaper(with: wallpaperViewModel.currentWallpaper)
        startListening()
        
        // 显示桌面壁纸
        self.wallpaperWindow.orderFront(nil)
        
        if viewModel.isFirstLaunch {
            self.mainWindowController.window.center()
            self.mainWindowController.window.makeKeyAndOrderFront(nil)
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !self.mainWindowController.window.isVisible && !settingsWindow.isVisible {
            self.mainWindowController.window?.makeKeyAndOrderFront(nil)
        }
        
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let wallpaper = UserDefaults.standard.url(forKey: "OSWallpaper") {
            try? NSWorkspace.shared.setDesktopImageURL(wallpaper, for: .main!)
        }
        
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        do {
            let filesURL = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: .skipsHiddenFiles)
            for url in filesURL {
                if url.lastPathComponent.contains("staticWP") {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            print(error)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

// MARK: - misc methods
    @objc func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow.center()
        self.settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func openMainWindow() {
        self.mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor @objc func toggleFilter() {
        self.contentViewModel.isFilterReveal.toggle()
    }
    
// MARK: Set Settings Window
    func setSettingsWindow() {
        self.settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        self.settingsWindow.title = "Settings"
        self.settingsWindow.isReleasedWhenClosed = false
        self.settingsWindow.toolbarStyle = .preference
        
        self.settingsWindow.delegate = self
        
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        
        toolbar.selectedItemIdentifier = SettingsToolbarIdentifiers.performance
        
        self.settingsWindow.toolbar = toolbar
        self.settingsWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(self.viewModel))
    }
    
// MARK: Set Wallpaper Window - Most efforts
    func setWallpaperWindow() {
        self.wallpaperWindow = NSWindow()
        self.wallpaperWindow.styleMask = [.borderless, .fullSizeContentView]
        self.wallpaperWindow.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        self.wallpaperWindow.collectionBehavior = [.stationary, .canJoinAllSpaces]
        
        self.wallpaperWindow.setFrame(NSRect(origin: .zero,
                                             size: CGSize(width: NSScreen.main!.frame.size.width,
                                                          height: NSScreen.main!.frame.size.height)
                                            ),
                                      display: true)
        self.wallpaperWindow.isMovable = false
        self.wallpaperWindow.titlebarAppearsTransparent = true
        self.wallpaperWindow.titleVisibility = .hidden
        self.wallpaperWindow.canHide = false
        self.wallpaperWindow.canBecomeVisibleWithoutLogin = true
        self.wallpaperWindow.isReleasedWhenClosed = false
        self.wallpaperWindow.contentView = NSHostingView(rootView:
            WallpaperView(viewModel: self.wallpaperViewModel)
        )
    }
    
    func windowWillClose(_ notification: Notification) {
        viewModel.reset()
    }
    
    func setEventHandler() {
        self.eventHandler = NSEvent.addGlobalMonitorForEvents(matching: .any) { [weak self] event in
            // contentView.subviews.first -> SwiftUIView.subviews.first -> WKWebView
            if let webview = self?.wallpaperWindow.contentView?.subviews.first?.subviews.first,
               let frontmostApplication = NSWorkspace.shared.frontmostApplication,
                   webview is WKWebView,
                   frontmostApplication.bundleIdentifier == "com.apple.finder" {
                switch event.type {
                case .scrollWheel:
                    webview.scrollWheel(with: event)
                case .mouseMoved:
                    webview.mouseMoved(with: event)
                case .mouseEntered:
                    webview.mouseEntered(with: event)
                case .mouseExited:
                    webview.mouseExited(with: event)

                case .leftMouseUp:
                    fallthrough
                case .rightMouseUp:
                    webview.mouseUp(with: event)
                    
                case .leftMouseDown:
                    webview.mouseDown(with: event)
    //            case .rightMouseDown:
    //                view?.mouseDown(with: event)
                    
                case .leftMouseDragged:
                    fallthrough
                case .rightMouseDragged:
                    webview.mouseDragged(with: event)
                    
                default:
                    break
                }
            }
        }
    }
    
    @objc func startListening() {
        stopListening()
        if viewModel.settings.EnablePlaylist {
            let hourToSecond = Int(viewModel.settings.hourText)! * 3600
            let minuteToSecond = Int(viewModel.settings.minuteText)! * 60
            timer = Timer.scheduledTimer(
                timeInterval: TimeInterval(hourToSecond + minuteToSecond),
                target: self,
                selector: #selector(switchPlayList),
                userInfo: nil,
                repeats: true
            )
            RunLoop.main.add(timer!, forMode: .common)
            print("启动计时监听器：\(hourToSecond + minuteToSecond)")
        }
    }
    
    @objc func stopListening() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func switchPlayList() {
        let playList = UserDefaults.standard.string(forKey: "PlayList")?.split(separator: "|").compactMap{ "\($0)" }
        if !(playList == nil) {
            if playList!.count > 1 {
                print("模式: ", viewModel.settings.playOrder)
                let wallpaperName = wallpaperViewModel.currentWallpaper.wallpaperDirectory.absoluteString.split(separator: "/").compactMap({ "\($0)" }).last!
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
                    setWallpaper2(wallpaperName: playList![randomIndex])
                } else {
                    var nextWallpaperIndex = -1
                    for index in stride(from: 0, through: playList!.count - 1, by: 1) {
                        if wallpaperName == playList![index] {
                            if index != (playList!.count - 1){
                                nextWallpaperIndex = index + 1
                            }
                            else {
                                nextWallpaperIndex = 0
                            }
                        }
                    }
                    if nextWallpaperIndex != -1 {
                        setWallpaper2(wallpaperName: playList![nextWallpaperIndex])
                        print("下一个壁纸: ", playList![nextWallpaperIndex].removingPercentEncoding ?? "", "序号: ", nextWallpaperIndex)
                    }
                    else {
                        setWallpaper2(wallpaperName: playList![0])
                        print("未找到当前播放的壁纸：", wallpaperName.removingPercentEncoding!, "\n从头播放：", playList![0].removingPercentEncoding ?? "");
                    }
                }
            } else {
                print("播放列表壁纸过少，取消切换")
            }
        }
    }
    
    @objc func setWallpaper2(wallpaperName: String) {
        if let json = UserDefaults.standard.data(forKey: wallpaperName),
           let wallpaper = try? JSONDecoder().decode(WEWallpaper.self, from: json) {
            AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = wallpaper
        } else {
            AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = WEWallpaper(using: .invalid, where: Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!)
        }
    }
    
    @objc func setWallpaper(_ item: NSMenuItem) {
        let recentWallpaper = (item.representedObject as! String).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        if let json = UserDefaults.standard.data(forKey: recentWallpaper!),
                let wallpaper = try? JSONDecoder().decode(WEWallpaper.self, from: json) {
                AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = wallpaper
            } else {
                AppDelegate.shared.wallpaperViewModel.nextCurrentWallpaper = WEWallpaper(using: .invalid, where: Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!)
            }
    }
    
    @objc func setRecent(newWallpaperDictionary: String, newWallpaperName: String) -> Bool {
        let wallpaperMeta = newWallpaperDictionary.removingPercentEncoding! + "˘" + newWallpaperName
        let recentWallpapersMenu = NSMenu(title: String(localized: "Recent Wallpapers"))
        var recentWallpapers = UserDefaults.standard.string(forKey: "RecentWallpapers")
        if recentWallpapers?.isEmpty != false {
            recentWallpapers = String("|")
        }
        var recentWallpapersArray = recentWallpapers?.split(separator: "|").compactMap{ "\($0)" }
        if recentWallpapersArray!.count > 0 {
            if recentWallpapersArray![0] == wallpaperMeta {
                return false
            }
        }
        print("添加最近壁纸", wallpaperMeta)
        if !viewModel.settings.switchAfterFinish {
            startListening()
        }
        if wallpaperMeta.removingPercentEncoding == "WallpaperNotFound.mp4" {
            print("目前无壁纸")
            return false
        }
        recentWallpapers = "|" + wallpaperMeta + recentWallpapers!
        recentWallpapersArray = recentWallpapers?.split(separator: "|").compactMap{ "\($0)" }
        if recentWallpapersArray!.count > Int(viewModel.settings.recentWallpaperCount)! {
            var index = 0
            recentWallpapers = String("|")
            for wallpaperName in recentWallpapersArray! {
                if index == Int(viewModel.settings.recentWallpaperCount) {
                    break
                }
                recentWallpapers = recentWallpapers! + wallpaperName + "|"
                index += 1
            }
            recentWallpapersArray = recentWallpapers?.split(separator: "|").compactMap{ "\($0)" }
        }
        UserDefaults.standard.set(recentWallpapers, forKey: "RecentWallpapers")
        recentWallpapersMenu.items = []
        for wallpaperName in recentWallpapersArray! {
            var metaInfo = wallpaperName.split(separator: "˘").compactMap{ "\($0)" }
            if metaInfo.count < 2 {
                metaInfo.append(wallpaperName.removingPercentEncoding!)
            }
            let nsMenuItem: NSMenuItem = NSMenuItem(title: metaInfo[1], action: #selector(AppDelegate.shared.setWallpaper), keyEquivalent: "")
            nsMenuItem.representedObject = metaInfo[0]
            recentWallpapersMenu.items.append(nsMenuItem)
        }
        AppDelegate.shared.statusItem.menu!.items[1].submenu = recentWallpapersMenu
        return true
    }
    
    func saveCurrentWallpaper() {
        if !viewModel.settings.changeWallpaper {
            print("未启用，取消更改系统壁纸")
            return
        }
        var wallpaper: URL {
            var osWallpaper: URL { NSWorkspace.shared.desktopImageURL(for: .main!)! }
            if let wallpaper = UserDefaults.standard.url(forKey: "OSWallpaper") {
                if wallpaper != osWallpaper {
                    if !wallpaper.lastPathComponent.contains("staticWP") {
                        return wallpaper
                    }
                }
            }
            return osWallpaper
        }
        UserDefaults.standard.set(wallpaper, forKey: "OSWallpaper")
    }
    
    func setPlacehoderWallpaper(with wallpaper: WEWallpaper) {
        if viewModel.settings.EnablePlaylist {
            let hourToSecond = Int(viewModel.settings.hourText)! * 3600
            let minuteToSecond = Int(viewModel.settings.minuteText)! * 60
            let timeInterval = Date().timeIntervalSince1970
            let addTiming: Double = timeInterval + Double(hourToSecond) + Double(minuteToSecond)
            UserDefaults.standard.set(addTiming, forKey: "SwitchWallpaperTiming")
        }
        if let json = UserDefaults.standard.data(forKey: "CurrentWallpaper"),
           let playingWallpaper = try? JSONDecoder().decode(WEWallpaper.self, from: json) {
            if playingWallpaper.wallpaperDirectory.absoluteString == wallpaper.wallpaperDirectory.absoluteString {
                print("当前壁纸相同，取消更改")
                return
            }
        }
        let isChange = setRecent(newWallpaperDictionary: wallpaper.wallpaperDirectory.absoluteString.split(separator: "/").compactMap({ "\($0)" }).last!, newWallpaperName: wallpaper.project.title)
        if !viewModel.settings.changeWallpaper {
            print("未启用，取消更改壁纸")
            return
        }
        if isChange == false {
            print("拦截多次更改壁纸")
            return
        }
        print("更改壁纸")
        switch wallpaper.project.type {
        case "video":
            let asset = AVAsset(url: wallpaper.wallpaperDirectory.appending(component: wallpaper.project.file))
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTimeMake(value: 1, timescale: 1) // 第一帧的时间
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, error in
                if let error = error {
                    print(error)
                } else if let cgImage = cgImage {
                    let nsImage = NSImage(cgImage: cgImage, size: .zero)
                    if let data = nsImage.tiffRepresentation {
                        do {
                            let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "staticWP_\(wallpaper.wallpaperDirectory.hashValue).tiff")
                            try data.write(to: url, options: .atomic)
                            try NSWorkspace.shared.setDesktopImageURL(url, for: .main!)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        default:
            return
        }
    }
}

enum SettingsToolbarIdentifiers {
    static let performance = NSToolbarItem.Identifier(rawValue: "performance")
    static let general = NSToolbarItem.Identifier(rawValue: "general")
    static let plugins = NSToolbarItem.Identifier(rawValue: "plugins")
    static let about = NSToolbarItem.Identifier(rawValue: "about")
}
