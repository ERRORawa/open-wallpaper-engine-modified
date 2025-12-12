//
//  WebWallpaperView.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/13.
//

import Cocoa
import SwiftUI
import WebKit

struct WebWallpaperView: NSViewRepresentable {
    @ObservedObject var wallpaperViewModel: WallpaperViewModel
    @StateObject var viewModel: WebWallpaperViewModel
    
    init(wallpaperViewModel: WallpaperViewModel) {
        self.wallpaperViewModel = wallpaperViewModel
        self._viewModel = StateObject(wrappedValue: WebWallpaperViewModel(wallpaper: wallpaperViewModel.currentWallpaper))
    }
    
    func readTextAndConvertToJSON(filePath: String) -> Any? {
        do {
            let textContent = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8)
            guard let jsonData = textContent.data(using: .utf8) else {
                return nil
            }
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
            return jsonObject
            
        } catch {
            return nil
        }
    }
    
    func convertDictToJSONString(dict:  NSMutableDictionary, prettyPrinted: Bool = false) -> String? {
        do {
            let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : []
            
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: options)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            return jsonString
            
        } catch {
            return nil
        }
    }
    
    func extractPropertiesDict(from rootDict:  NSMutableDictionary, tree: String) ->  NSMutableDictionary? {
        let general = rootDict["general"] as?  NSMutableDictionary
        let properties = general!["properties"] as?  NSMutableDictionary
        return properties
    }
    
    func makeNSView(context: Context) -> WKWebView {
        var jsCode = ""
        let filePath: String = wallpaperViewModel.currentWallpaper.wallpaperDirectory.path() + "project.json"
        let rootJSON = readTextAndConvertToJSON(filePath: filePath)
        if let rootDict = rootJSON as?  NSMutableDictionary {
            if let propertiesDict = extractPropertiesDict(from: rootDict, tree: "properties") {
                AppDelegate.shared.webProperties = propertiesDict
                if let propertiesString = convertDictToJSONString(dict: propertiesDict) {
                    jsCode = "window.properties = \(propertiesString)"
                }
            }
        }
        let userScript = WKUserScript(
            source: jsCode,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        let webConfig = WKWebViewConfiguration()
        webConfig.userContentController = userContentController
        
        AppDelegate.shared.nsView = WKWebView(frame: .zero, configuration: webConfig)
        
        AppDelegate.shared.nsView.navigationDelegate = viewModel
        
        AppDelegate.shared.nsView.loadFileURL(viewModel.fileUrl, allowingReadAccessTo: viewModel.readAccessURL)
        return AppDelegate.shared.nsView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let selectedWallpaper = wallpaperViewModel.currentWallpaper
        let currentWallpaper = viewModel.currentWallpaper
        
        if selectedWallpaper.wallpaperDirectory.appending(path: selectedWallpaper.project.file) != currentWallpaper.wallpaperDirectory.appending(path: currentWallpaper.project.file) {
            viewModel.currentWallpaper = selectedWallpaper
            nsView.loadFileURL(viewModel.fileUrl, allowingReadAccessTo: viewModel.readAccessURL)
        }
    }
}
