//
//  ExplorerItem.swift
//  Open Wallpaper Engine
//
//  Created by Haren on 2023/8/25.
//

import SwiftUI

struct ExplorerItem: SubviewOfContentView {
    
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject var wallpaperViewModel: WallpaperViewModel
    
    var wallpaper: WEWallpaper
    var index: Int
    @State var playList: String?
    @State var wallpaperName: String
    
    init(viewModel: ContentViewModel, wallpaperViewModel: WallpaperViewModel, addPlayListChecked: Bool = false, wallpaper: WEWallpaper, index: Int, playList: [String]? = nil, idList: [Int]? = nil) {
        self.viewModel = viewModel
        self.wallpaperViewModel = wallpaperViewModel
        self.playList = (UserDefaults.standard.string(forKey: "PlayList") ?? "|")
        self.wallpaper = wallpaper
        self.index = index
        self.wallpaperName = self.wallpaper.wallpaperDirectory.absoluteString.split(separator: "/").compactMap({ "\($0)" }).last!
        
        if UserDefaults.standard.object(forKey: self.wallpaperName) == nil {
            print("未找到持久化数据，重新生成: ", self.wallpaperName.removingPercentEncoding ?? "无壁纸")
            UserDefaults.standard.set(try! JSONEncoder().encode(self.wallpaper), forKey: self.wallpaperName)
        }
    }
    
var body: some View {
        ZStack(alignment: .top) {
            GifImage(contentsOf: { (url: URL) in
                if let selectedProject = try? JSONDecoder()
                    .decode(WEProject.self, from: Data(contentsOf: url.appending(path: "project.json"))) {
                    return url.appending(path: selectedProject.preview)
                }
                return Bundle.main.url(forResource: "WallpaperNotFound", withExtension: "mp4")!
            }(wallpaper.wallpaperDirectory))
            .resizable()
            .scaleEffect(viewModel.imageScaleIndex == index ? 1.2 : 1.0)
            .aspectRatio(1.0, contentMode: .fit)
            .clipped()
            .onTapGesture {
                wallpaperViewModel.nextCurrentWallpaper = wallpaper
            }
            .onReceive(AppDelegate.shared.$changePlayList) { newValue in
                if newValue == index {
                    print("更改播放列表，视频序号：", index)
                    AppDelegate.shared.changePlayList = -1
                    playList = (UserDefaults.standard.string(forKey: "PlayList") ?? "|")
                    if (playList?.contains("|" + wallpaperName + "|")) == false {
                        playList = String((playList ?? "|") + wallpaperName + "|")
                        UserDefaults.standard.set(try! JSONEncoder().encode(wallpaper), forKey: wallpaperName)
                    }
                    else{
                        playList = playList?.replacingOccurrences(of: String(wallpaperName + "|"), with: "")
                        UserDefaults.standard.removeObject(forKey: wallpaperName)
                    }
                    UserDefaults.standard.set(playList, forKey: "PlayList")
                }
            }
            VStack(alignment: .trailing) {
                Toggle("", isOn: Binding<Bool>(get: {
                    playList?.contains("|" + wallpaperName + "|") != false
                }, set: {
                    playList = (UserDefaults.standard.string(forKey: "PlayList") ?? "|")
                    if $0 {
                        if (playList?.contains("|" + wallpaperName + "|")) == false {
                            playList = String((playList ?? "|") + wallpaperName + "|")
                            UserDefaults.standard.set(try! JSONEncoder().encode(wallpaper), forKey: wallpaperName)
                        }
                    } else {
                        if (playList?.contains("|" + wallpaperName + "|")) != false {
                            playList = playList?.replacingOccurrences(of: String(wallpaperName + "|"), with: "")
                            UserDefaults.standard.removeObject(forKey: wallpaperName)
                        }
                    }
                    UserDefaults.standard.set(playList, forKey: "PlayList")
                    print(String("列表: " + (playList ?? "错误")))
                }))
                Spacer()
                Text(wallpaper.project.title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .padding(4)
                    .background(Color(white: 0, opacity: viewModel.imageScaleIndex == index ? 0.4 : 0.2))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(white: viewModel.imageScaleIndex == index ? 0.9 : 0.7))
            }
        }
        .selected(wallpaper.wallpaperDirectory == wallpaperViewModel.currentWallpaper.wallpaperDirectory)
        .border(Color.accentColor, width: viewModel.imageScaleIndex == index ? 1.0 : 0)
        .environment(\.locale, Locale(identifier: AppDelegate.shared.languageState.localeIdentifier))
    }
}
