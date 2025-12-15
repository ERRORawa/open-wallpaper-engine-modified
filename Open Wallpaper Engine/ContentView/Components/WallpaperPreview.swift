//
//  WallpaperPreview.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/15.
//

import SwiftUI
import Combine

struct WallpaperPreview: SubviewOfContentView {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject var wallpaperViewModel: WallpaperViewModel
    
    @Environment(\.undoManager) var undoManager
    
    @State var dictKeys: [String] = []
    
    @State var sliderValues: [String: Int] = [:]
    
    @State var stringComboValues: [String: String] = [:]
    @State var intComboValues: [String: Int] = [:]
    
    @State var toggleValues: [String: Bool] = [:]
    
    @State var textValues: [String: String] = [:]
    
    @State var fileValues: [String: URL] = [:]
    @State var showFilePicker = false
    @State var isCancle = false
    @State var fileKey = ""
    @State var lastFile = "noFile.noFile"
    
    func sliderBinding(for key: String) -> Binding<Double> {
        Binding<Double>(
            get: { Double(sliderValues[key] ?? 0) },
            set: { newValue in sliderValues[key] = Int(newValue) }
        )
    }
    
    func stringComboBinding(for key: String) -> Binding<String> {
        Binding<String>(
            get: { stringComboValues[key] ?? "" },
            set: { newValue in
                stringComboValues[key] = newValue
                updateProperties(key: key, value: stringComboValues[key]!)
            }
        )
    }
    
    func intComboBinding(for key: String) -> Binding<Int> {
        Binding<Int>(
            get: { intComboValues[key] ?? 0 },
            set: { newValue in
                intComboValues[key] = newValue
                updateProperties(key: key, value: intComboValues[key]!)
            }
        )
    }
    
    func toggleBinding(for key: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { toggleValues[key] ?? false },
            set: { newValue in
                toggleValues[key] = newValue
                updateProperties(key: key, value: toggleValues[key]!)
            }
        )
    }
    
    func textBinding(for key: String) -> Binding<String> {
        Binding<String>(
            get: { textValues[key] ?? ""},
            set: { newValue in textValues[key] = newValue }
        )
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
    
    func updateProperties(key: String, value: Any) {
        let newDict = AppDelegate.shared.webProperties[key] as! NSMutableDictionary
        newDict["value"] = value
        AppDelegate.shared.webProperties[key] = newDict
        let newJS = AppDelegate.shared.webProperties
        if newDict["type"] as! String == "file" {
            if isCancle {
                isCancle = false
                print("用户取消操作")
                return
            }
            let fileURL = value as! URL
            if fileURL.lastPathComponent == "remove" {
                newDict.removeObject(forKey: "value")
                fileValues.removeValue(forKey: key)
                let wallpaperDir = wallpaperViewModel.currentWallpaper.wallpaperDirectory
                let lastURL = wallpaperDir.appendingPathComponent(lastFile)
                do {
                    if FileManager.default.fileExists(atPath: lastURL.path()) {
                        try FileManager.default.removeItem(at: lastURL)
                    }
                } catch {
                    print("删除文件失败：\(error.localizedDescription)")
                }
                lastFile = "noFile.noFile"
            } else {
                let wallpaperDir = wallpaperViewModel.currentWallpaper.wallpaperDirectory
                var fileName = fileURL.lastPathComponent
                if fileName == lastFile {
                    fileName = "1" + lastFile
                }
                let destURL = wallpaperDir.appendingPathComponent(fileName)
                let lastURL = wallpaperDir.appendingPathComponent(lastFile)
                do {
                    if FileManager.default.fileExists(atPath: lastURL.path()) {
                        try FileManager.default.removeItem(at: lastURL)
                    }
                    if FileManager.default.fileExists(atPath: destURL.path()) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                } catch {
                    print("复制文件失败：\(error.localizedDescription)")
                }
                lastFile = fileName
                newDict["value"] = destURL.path()
            }
            newJS[key] = newDict
        }
        var javascriptStyle = ""
        if let propertiesString = convertDictToJSONString(dict: newJS) {
            javascriptStyle = "window.properties = \(propertiesString);wallpaperPropertyListener.applyUserProperties(properties)"
            print(javascriptStyle)
        }
        AppDelegate.shared.nsView.evaluateJavaScript(javascriptStyle, completionHandler: nil)
    }
    
    func log(any: Any) -> Bool {
        print(any)
        return false
    }
    
    func multiText(texts: [String]) -> some View {
        VStack(alignment: .leading){
            ForEach(0...texts.count - 1, id: \.self) { i in
                if i == 0 {
                    Text(texts[i])
                } else {
                    Text(texts[i])
                        .font(.footnote)
                }
            }
        }
    }
    
    func cover(text: String) -> [String] {
        let htmlCodes = ["<\\s*br\\s*\\/?>", "<\\/?\\s*small\\s*>"]
        let markdownCodes = ["\n", "`"]
        do {
            var result = text
            for index in 0...htmlCodes.count - 1 {
                let regex = try NSRegularExpression(pattern: htmlCodes[index], options: [.caseInsensitive])
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: markdownCodes[index]
                )
            }
            return result.components(separatedBy: "`")
        } catch {
            print("正则表达式错误: \(error)")
            return text.components(separatedBy: "`")
        }
    }
    
    @State var isEditingId = ""
    @State var title = ""
    @State var newTag = ""
    
    @State var hoveredTag: String?
    @State var isTagsHovered = false
    
    init(contentViewModel viewModel: ContentViewModel, wallpaperViewModel: WallpaperViewModel) {
        self.viewModel = viewModel
        self.wallpaperViewModel = wallpaperViewModel
    }
    
    var wallpaperSize: String {
        guard let sizeBytes = try? wallpaperViewModel.currentWallpaper.wallpaperDirectory.directoryTotalAllocatedSize(includingSubfolders: true) 
        else {
            return "??? MB"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack {
                        GifImage(contentsOf: { (url: URL) in
                            if let selectedProject = try? JSONDecoder()
                                .decode(WEProject.self, from: Data(contentsOf: url.appending(path: "project.json"))) {
                                return url.appending(path: selectedProject.preview)
                            }
                            return Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!
                        }(wallpaperViewModel.currentWallpaper.wallpaperDirectory))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 16.0))
                            .frame(width: 280, height: 280)
                        HStack {
                            if isEditingId == "title" {
                                TextField("Wallpaper Title", text: $title)
                                    .onSubmit {
                                        var wallpaper = wallpaperViewModel.currentWallpaper
                                        
                                        wallpaper.project.title = title
                                        
                                        guard let data = try? JSONEncoder().encode(wallpaper.project) else { return }
                                        
                                        try? data.write(to: wallpaper.wallpaperDirectory.appending(path: "project.json"), options: .atomic)
                                        
                                        wallpaperViewModel.currentWallpaper = wallpaper
                                        
                                        isEditingId = ""
                                    }
                            } else {
                                Text(wallpaperViewModel.currentWallpaper.project.title.isEmpty ? "Untitled" : wallpaperViewModel.currentWallpaper.project.title)
                                    .frame(minWidth: 50)
                                    .id("title")
                                    .lineLimit(1)
                                    .onTapGesture(count: 2) {
                                        title = wallpaperViewModel.currentWallpaper.project.title
                                        isEditingId = "title"
                                    }
                                Image(systemName: "square.and.pencil")
                            }
                            
                        }
                    }
                    HStack {
                        Image("we.placeholder")
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text("Unkown Author")
                    }
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "star")
                            Image(systemName: "star")
                            Image(systemName: "star")
                            Image(systemName: "star")
                            Image(systemName: "star")
                        }
                        .font(.caption)
                        Button { } label: {
                            Image(systemName: "heart")
                        }
                        .disabled(true)
                    }
                    HStack {
                        Text(wallpaperViewModel.currentWallpaper.project.type)
                        Text(wallpaperSize)
                    }
                    .font(.footnote)
                    
                    ViewThatFits(in: .horizontal) {
                        tags.animation(.spring(), value: isTagsHovered)
                        ScrollView(.horizontal, showsIndicators: false) {
                            tags.animation(.spring(), value: isTagsHovered)
                        }
                    }
                    
                    .onHover { isTagsHovered = $0 }
                    
                    if isEditingId == "tags" {
                        HStack {
                            Button {
                                newTag = ""
                                isEditingId = ""
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            TextField("New Tag", text: $newTag)
                                .onSubmit {
                                    defer {
                                        newTag = ""
                                        isEditingId = ""
                                    }
                                    
                                    guard !newTag.isEmpty else { return }
                                    
                                    var wallpaper = wallpaperViewModel.currentWallpaper
                                    
                                    var tags = wallpaper.project.tags ?? []
                                    
                                    tags = Array(Set(tags)) // remove duplicate items
                                    
                                    tags.append(newTag)
                                    
                                    tags = Array(Set(tags)) // remove duplicate items
                                    
                                    wallpaper.project.tags = tags.sorted()
                                    
                                    guard let data = try? JSONEncoder().encode(wallpaper.project) else { return }
                                    
                                    try? data.write(to: wallpaper.wallpaperDirectory.appending(path: "project.json"), options: .atomic)
                                    
                                    wallpaperViewModel.currentWallpaper = wallpaper
                                }
                        }
                    }
                    VStack(spacing: 3) {
                        Button { } label: {
                            Label("Unsubscribe", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        HStack(spacing: 3) {
                            Button { } label: {
                                Label("Comment", systemImage: "text.badge.star")
                                    .frame(maxWidth: .infinity)
                            }
                            Button { } label: {
                                Image(systemName: "doc.on.doc.fill")
                            }
                            Button { } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                        }
                    }
                    .disabled(true)
                    // MARK: Properties
                    HStack(spacing: 3) {
                        Text("Properties")
                        VStack {
                            Divider()
                                .frame(height: 1)
                                .overlay(Color.accentColor)
                        }
                    }
                    VStack(spacing: 16) {
                        ColorPicker(selection: .constant(.red), supportsOpacity: true) {
                            HStack {
                                Label("Scheme Color", systemImage: "paintpalette.fill")
                                Spacer()
                            }
                        }
                        .opacity(0.5)
                        .disabled(true)
                        switch wallpaperViewModel.currentWallpaper.project.type.lowercased() {
                        case "video":
                            HStack {
                                Label("Volume", systemImage: "speaker.wave.3.fill")
                                Spacer()
                                Slider(value: $wallpaperViewModel.playVolume, in: 0...1).frame(width: 100)
                                Text(String(format: "%.0f", wallpaperViewModel.playVolume * 100) + "%")
                                    .frame(width: 35)
                            }
                            HStack {
                                Label("Playback Rate", systemImage: "play.fill")
                                Spacer()
                                Slider(value: $wallpaperViewModel.playRate, in: 0...2, step: 0.1).frame(width: 100)
                                Text(String(format: "%.01fx", wallpaperViewModel.playRate))
                                    .frame(width: 35)
                            }
                        case "web":
                            VStack {
                                ForEach(dictKeys, id: \.self) { key in
                                    let dict = AppDelegate.shared.webProperties[key] as!  NSMutableDictionary
                                    let htmlLabel = dict["text"] as! String
                                    let label = cover(text: htmlLabel)
                                    let type = dict["type"] as? String ?? "No Type"
                                    switch type {
                                    case "slider":
                                        let min = dict["min"] as! Double
                                        let max = dict["max"] as! Double
                                        let value = dict["value"] as! Int
                                        HStack {
                                            multiText(texts: label)
                                            Spacer()
                                            Slider(
                                                value: sliderBinding(for: key),
                                                in: min...max,
                                                onEditingChanged: { isEditing in
                                                    if !isEditing {
                                                        updateProperties(key: key, value: sliderValues[key]!)
                                                    }
                                                }
                                            )
                                                .frame(width: 80)
                                            Text("\(sliderValues[key] ?? 0)")
                                                .frame(width: 30)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.1)
                                        }
                                        .onAppear {
                                            sliderValues[key] = value
                                        }
                                    case "combo":
                                        let stringOptions = dict["options"] as? [[String: String]]
                                        if stringOptions != nil {
                                            let value = dict["value"] as? String ?? ""
                                            HStack {
                                                multiText(texts: label)
                                                Spacer()
                                                Picker("", selection: stringComboBinding(for: key)) {
                                                    ForEach(stringOptions!, id: \.["value"]) { option in
                                                        Text(option["label"]!).tag(option["value"]!)
                                                    }
                                                }
                                            }
                                            .onAppear {
                                                stringComboValues[key] = value
                                            }
                                        } else {
                                            let options = dict["options"] as? [[String: Any]]
                                            var parsedOptions: [(label: String, value: Int)] {
                                                options!.compactMap { dict in
                                                    guard let label = dict["label"] as? String,
                                                          let valueNum = dict["value"] as? NSNumber,
                                                          let value = Int(exactly: valueNum) else {
                                                        return nil
                                                    }
                                                    return (label: label, value: value)
                                                }
                                            }
                                            let value = dict["value"] as? Int ?? 0
                                            HStack {
                                                multiText(texts: label)
                                                Spacer()
                                                Picker("", selection: intComboBinding(for: key)) {
                                                    ForEach(parsedOptions, id: \.value) { option in
                                                        Text(option.label).tag(option.value)
                                                    }
                                                }
                                            }
                                            .onAppear {
                                                intComboValues[key] = value
                                            }
                                        }
                                    case "bool":
                                        let value = dict["value"] as? Bool ?? false
                                        HStack {
                                            multiText(texts: label)
                                            Spacer()
                                            Toggle("", isOn: toggleBinding(for: key))
                                        }
                                        .onAppear {
                                            toggleValues[key] = value
                                        }
                                    case "textinput":
                                        let value = dict["value"] as? String ?? ""
                                        HStack {
                                            multiText(texts: label)
                                            Spacer()
                                            TextField("Press Enter to Save", text: textBinding(for: key), onCommit: {
                                                updateProperties(key: key, value: textValues[key]!)
                                            })
                                                .frame(width: 150)
                                                .textFieldStyle(.roundedBorder)
                                                .border(Color(.blue))
                                        }
                                        .onAppear {
                                            textValues[key] = value
                                        }
                                    case "file":
                                        let value = ""
                                        HStack {
                                            multiText(texts: label)
                                            Spacer()
                                            VStack {
                                                if fileValues[key]?.lastPathComponent ?? "" == ""{
                                                    Text("Nothing Imported")
                                                        .scaleEffect(0.8, anchor: .bottom)
                                                        .offset(y: 5)
                                                    Button() {
                                                        fileKey = key
                                                        showFilePicker = true
                                                        ImageFilePicker(fileValues: $fileValues, isPresented: $showFilePicker, isCancle: $isCancle, key: fileKey).showPanel()
                                                        updateProperties(key: key, value: fileValues[key] ?? "")
                                                    } label: {
                                                        Image(systemName: "pencil.line")
                                                            .foregroundColor(Color(NSColor.systemBlue))
                                                            .frame(height: 16)
                                                        Text("Select file")
                                                    }
                                                }
                                                else {
                                                    Text(fileValues[key]?.lastPathComponent ?? "ERROR")
                                                        .scaleEffect(0.8, anchor: .bottom)
                                                        .offset(y: 5)
                                                    HStack {
                                                        Button() {
                                                            fileKey = key
                                                            showFilePicker = true
                                                            ImageFilePicker(fileValues: $fileValues, isPresented: $showFilePicker, isCancle: $isCancle, key: fileKey).showPanel()
                                                            updateProperties(key: key, value: fileValues[key]!)
                                                        } label: {
                                                            Image(systemName: "pencil.line")
                                                                .foregroundColor(Color(NSColor.systemBlue))
                                                                .frame(height: 16)
                                                        }
                                                        
                                                        Button() {
                                                            let workspace = NSWorkspace.shared
                                                            let wallpaperDirectory = wallpaperViewModel.currentWallpaper.wallpaperDirectory
                                                            workspace.activateFileViewerSelecting([wallpaperDirectory.appendingPathComponent(lastFile)])
                                                        } label: {
                                                            Image(systemName: "folder.fill")
                                                                .foregroundColor(Color(NSColor.systemBlue))
                                                                .frame(height: 16)
                                                        }
                                                        
                                                        Button() {
                                                            fileKey = key
                                                            fileValues[key] = URL(filePath: "remove")
                                                            updateProperties(key: key, value: fileValues[key]!)
                                                        } label: {
                                                            Image(systemName: "trash.fill")
                                                                .foregroundColor(.white)
                                                                .frame(height: 16)
                                                        }
                                                        .tint(Color(NSColor.systemRed))
                                                        .buttonStyle(.borderedProminent)
                                                    }
                                                }
                                            }
                                        }
                                        .onAppear {
                                            fileValues[key] = URL(string: value)
                                        }
                                    default:
                                        Text("\(key): \(type) NotSupport")
                                    }
                                }
                            }
                            .onReceive(AppDelegate.shared.$webProperties) { newDict in
                                dictKeys = newDict.allKeys.compactMap { ($0 as! String) }.filter { $0 != "schemecolor" }
                            }
                        default:
                            EmptyView()
                        }
                    }
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Text("Your Presets")
                            VStack {
                                Divider()
                                    .frame(height: 1)
                                    .overlay(Color.accentColor)
                            }
                        }
                        Group {
                            HStack(spacing: 3) {
                                Button { } label: {
                                    Label("Load", systemImage: "folder.fill")
                                        .frame(maxWidth: .infinity)
                                    
                                }
                                Button { } label: {
                                    Label("Save", systemImage: "square.and.arrow.down.fill")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            Button { } label: {
                                Label("Apply to all Wallpapers", systemImage: "list.bullet.rectangle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            Button { } label: {
                                Label("Share JSON", systemImage: "arrow.2.squarepath")
                                    .frame(maxWidth: .infinity)
                            }
                            Button { } label: {
                                Label("Reset", systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .disabled(true)
                    }
                }
                .blur(radius: wallpaperViewModel.currentWallpaper.project == .invalid ? 16.0 : 0)
                .overlay {
                    if wallpaperViewModel.currentWallpaper.project == .invalid {
                        Text("Please select a valid wallpaper")
                    }
                }
                .disabled(wallpaperViewModel.currentWallpaper.project == .invalid ? true : false)
                .animation(.default, value: wallpaperViewModel.currentWallpaper.project)
                .padding([.horizontal, .top])
            }

            HStack {
                Spacer()
                Button {
                    AppDelegate.shared.mainWindowController.close()
                } label: {
                    Text("OK").frame(width: 50)
                }
                .buttonStyle(.borderedProminent)
                Button { 
                    AppDelegate.shared.mainWindowController.close()
                } label: {
                    Text("Cancel").frame(width: 50)
                }
            }
            .padding()
        }
        .environment(\.locale, Locale(identifier: AppDelegate.shared.languageState.localeIdentifier))
    }
    
    /// Shows all tags about current wallpaper in horizontal
    var tags: some View {
        HStack {
            if let tags = wallpaperViewModel.currentWallpaper.project.tags {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .padding(5)
                        .background {
                            RoundedRectangle(cornerRadius: 25.0)
                                .colorInvert()
                                .foregroundStyle(Color.primary)
                            RoundedRectangle(cornerRadius: 25.0)
                                .stroke(Color.secondary, lineWidth: 1.6)
                        }
                        .overlay(alignment: .topTrailing) {
                            if hoveredTag == tag {
                                Button {
                                    var wallpaper = wallpaperViewModel.currentWallpaper
                                    
                                    guard var tags = wallpaper.project.tags else { return } // else case seems impossible, however much safer
                                    
                                    tags = Array(Set(tags)) // remove duplicate items
                                    
                                    guard let index = tags.firstIndex(where: { $0 == tag }) else { return }
                                    
                                    tags.remove(at: index)
                                    
                                    wallpaper.project.tags = tags
                                    
                                    guard let data = try? JSONEncoder().encode(wallpaper.project) else { return }
                                    
                                    try? data.write(to: wallpaper.wallpaperDirectory.appending(path: "project.json"), options: .atomic)
                                    
                                    wallpaperViewModel.currentWallpaper = wallpaper
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white, .red)
                                .symbolRenderingMode(.palette)
                                .offset(x: 5, y: -2.5)
                            }
                        }
                        .onHover { hovered in
                            if hovered {
                                hoveredTag = tag
                            } else {
                                hoveredTag = nil
                            }
                        }
                }
            } else {
                Text("No Tags")
                    .foregroundStyle(Color.secondary)
            }
            
            if isTagsHovered {
                Button {
                    isEditingId = "tags"
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.footnote)
        .lineLimit(1)
    }
}

extension URL {
    /// check if the URL is a directory and if it is reachable
    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        return try checkResourceIsReachable()
    }

    /// returns total allocated size of a the directory including its subFolders or not
    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else { return nil }
        if includingSubfolders {
            guard
                let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
            return try urls.lazy.reduce(0) {
                    (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
            }
        }
        return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
                 (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    .totalFileAllocatedSize ?? 0) + $0
        }
    }
}
