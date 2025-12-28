//
//  WebWallpaperView.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/13.
//

import Cocoa
import SwiftUI
import WebKit
import Network

struct WebWallpaperView: NSViewRepresentable {
    @ObservedObject var wallpaperViewModel: WallpaperViewModel
    @StateObject var viewModel: WebWallpaperViewModel
    
    let udpReceiver = UDPReceiver()
    
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
    
    func convertDictToJSONString(dict: NSMutableDictionary, prettyPrinted: Bool = false) -> String? {
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
    
    func extractPropertiesDict(from rootDict: NSMutableDictionary) -> NSMutableDictionary? {
        let general = rootDict["general"] as? NSMutableDictionary
        AppDelegate.shared.webLocalization = general!["localization"] as? NSMutableDictionary ?? [:]
        let properties = general!["properties"] as? NSMutableDictionary
        return properties
    }
    
    func makeNSView(context: Context) -> WKWebView {
        var jsCode = ""
        let filePath: String = wallpaperViewModel.currentWallpaper.wallpaperDirectory.path() + "project.json"
        let rootJSON = readTextAndConvertToJSON(filePath: filePath)
        if let rootDict = rootJSON as? NSMutableDictionary {
            if let propertiesDict = extractPropertiesDict(from: rootDict) {
                AppDelegate.shared.webProperties = propertiesDict
                if let propertiesString = convertDictToJSONString(dict: propertiesDict) {
                    jsCode = "function wallpaperAudioListener(audioArray){};function wallpaperRegisterAudioListener(Func){wallpaperAudioListener = Func;};window.properties = \(propertiesString)"
                }
            }
        }
        if wallpaperViewModel.currentWallpaper.project.general?.supportsaudioprocessing ?? false {
            udpReceiver.onSpectrumReceived = nil
            udpReceiver.onSpectrumReceived = { spectrum in
                let spectrumArray = spectrum.map { String($0) }.joined(separator: ",")
                let jsCode = "wallpaperAudioListener([\(spectrumArray)]);"
                
                DispatchQueue.main.async {
                    AppDelegate.shared.nsView.evaluateJavaScript(jsCode, completionHandler: nil)
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
        webConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webConfig.userContentController = userContentController
        
        AppDelegate.shared.nsView = WKWebView(frame: .zero, configuration: webConfig)
        
        AppDelegate.shared.nsView.navigationDelegate = viewModel
        
        AppDelegate.shared.nsView.loadFileURL(viewModel.fileUrl, allowingReadAccessTo: viewModel.readAccessURL)
        
        if AppDelegate.shared.viewModel.settings.switchAfterFinish {
            AppDelegate.shared.startListening()
        }
        return AppDelegate.shared.nsView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let selectedWallpaper = wallpaperViewModel.currentWallpaper
        let currentWallpaper = viewModel.currentWallpaper
        
        var jsCode = ""
        let filePath: String = selectedWallpaper.wallpaperDirectory.path() + "project.json"
        let rootJSON = readTextAndConvertToJSON(filePath: filePath)
        if let rootDict = rootJSON as?  NSMutableDictionary {
            if let propertiesDict = extractPropertiesDict(from: rootDict) {
                AppDelegate.shared.webProperties = propertiesDict
                if let propertiesString = convertDictToJSONString(dict: propertiesDict) {
                    jsCode = "window.properties = \(propertiesString);wallpaperPropertyListener.applyUserProperties(properties)"
                }
            }
        }
        if wallpaperViewModel.currentWallpaper.project.general?.supportsaudioprocessing ?? false {
            udpReceiver.onSpectrumReceived = nil
            udpReceiver.onSpectrumReceived = { spectrum in
                let spectrumArray = spectrum.map { String($0) }.joined(separator: ",")
                let jsCode = "wallpaperAudioListener([\(spectrumArray)]);"
                
                DispatchQueue.main.async {
                    AppDelegate.shared.nsView.evaluateJavaScript(jsCode, completionHandler: nil)
                }
            }
        }
        nsView.evaluateJavaScript(jsCode, completionHandler: nil)
        if selectedWallpaper.wallpaperDirectory.appending(path: selectedWallpaper.project.file) != currentWallpaper.wallpaperDirectory.appending(path: currentWallpaper.project.file) {
            viewModel.currentWallpaper = selectedWallpaper
            nsView.loadFileURL(viewModel.fileUrl, allowingReadAccessTo: viewModel.readAccessURL)
        }
        if AppDelegate.shared.viewModel.settings.switchAfterFinish {
            AppDelegate.shared.startListening()
        }
    }
}

class UDPReceiver: NSObject {
    var onSpectrumReceived: (([Float]) -> Void)?
    private var socket: FileHandle?
    private var receiveCount = 0
    
    override init() {
        super.init()
        setupSocket()
    }
    
    func setupSocket() {
        let udpSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP, 0, nil, nil)
        guard let udpSocket = udpSocket else {
            print("无法创建接收器")
            return
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(9999)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let addrData = NSData(bytes: &addr, length: MemoryLayout<sockaddr_in>.size)
        let result = CFSocketSetAddress(udpSocket, addrData as CFData)
        if result != .success {
            print("绑定地址失败")
            return
        }
        let fd = CFSocketGetNative(udpSocket)
        socket = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        socket?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.processReceivedData(data)
        }
    }
    
    func processReceivedData(_ data: Data) {
        guard data.count == 512 else {
            return
        }
        
        let floats = data.withUnsafeBytes { buffer -> [Float] in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
        
        guard floats.count == 128 else {
            return
        }
        
        var cleaned = [Float]()
        
        for value in floats {
            var cleanValue = value
            
            if cleanValue.isNaN || cleanValue.isInfinite {
                cleanValue = 0.0
            }
            
            cleanValue = max(0.0, min(1.0, cleanValue))
            cleaned.append(cleanValue)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onSpectrumReceived?(cleaned)
        }
    }
    
    deinit {
        socket?.readabilityHandler = nil
        socket?.closeFile()
    }
}
