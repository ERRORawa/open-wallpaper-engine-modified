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
    var globalSettingsViewModel = GlobalSettingsViewModel()
    
    var importOpenPanel: NSOpenPanel!
    var nsView = WKWebView(frame: .zero)
    
    @Published var webProperties:  NSMutableDictionary = [:]
    
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
        
        // 显示桌面壁纸
        self.wallpaperWindow.orderFront(nil)
        
        if globalSettingsViewModel.isFirstLaunch {
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
        self.settingsWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(self.globalSettingsViewModel))
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
        globalSettingsViewModel.reset()
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
    
    @objc func setWallpaper(_ item: NSMenuItem) {
        let recentWallpapers = UserDefaults.standard.string(forKey: "RecentWallpapers")?.split(separator: "|").compactMap{ "\($0)" }
        if let json = UserDefaults.standard.data(forKey: recentWallpapers![item.tag]),
                let wallpaper = try? JSONDecoder().decode(WEWallpaper.self, from: json) {
                AppDelegate.shared.wallpaperViewModel.currentWallpaper = wallpaper
                AppDelegate.shared.saveCurrentWallpaper()
                AppDelegate.shared.setPlacehoderWallpaper(with: wallpaper)
                UserDefaults.standard.set(try! JSONEncoder().encode(AppDelegate.shared.wallpaperViewModel.currentWallpaper), forKey: "CurrentWallpaper")
            } else {
                AppDelegate.shared.wallpaperViewModel.currentWallpaper = WEWallpaper(using: .invalid, where: Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!)
            }
    }
    
    @objc func setRecent(newWallpaperName: String) -> Bool {
        let viewModel = GlobalSettingsViewModel()
        let recentWallpapersMenu = NSMenu(title: String(localized: "Recent Wallpapers"))
        var recentWallpapers = UserDefaults.standard.string(forKey: "RecentWallpapers")
        if recentWallpapers?.isEmpty != false {
            recentWallpapers = String("|")
        }
        var recentWallpapersArray = recentWallpapers?.split(separator: "|").compactMap{ "\($0)" }
        if recentWallpapersArray!.count > 0 {
            if recentWallpapersArray![0] == newWallpaperName {
                return false
            }
        }
        print("添加最近壁纸", newWallpaperName.removingPercentEncoding)
        if newWallpaperName.removingPercentEncoding == "WallpaperNotFound.mp4" {
            print("目前无壁纸")
            return false
        }
        recentWallpapers = "|" + newWallpaperName + recentWallpapers!
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
        var index = 0
        recentWallpapersMenu.items = []
        for wallpaperName in recentWallpapersArray! {
            var nsMenuItem: NSMenuItem = NSMenuItem(title: wallpaperName.removingPercentEncoding ?? "Decode error", action: #selector(AppDelegate.shared.setWallpaper), keyEquivalent: "")
            nsMenuItem.tag = index
            recentWallpapersMenu.items.append(nsMenuItem)
            index += 1
        }
        AppDelegate.shared.statusItem.menu!.items[1].submenu = recentWallpapersMenu
        return true
    }
    
    func saveCurrentWallpaper() {
        let viewModel = GlobalSettingsViewModel()
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
        let viewModel = GlobalSettingsViewModel()
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
        let isChange = setRecent(newWallpaperName: wallpaper.wallpaperDirectory.absoluteString.split(separator: "/").compactMap({ "\($0)" }).last!)
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
