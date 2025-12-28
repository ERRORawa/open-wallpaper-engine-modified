import SwiftUI
import AppKit
import UniformTypeIdentifiers
struct ImageFilePicker {
    @Binding var fileValues: [String: URL]
    @Binding var isPresented: Bool
    @Binding var isCancle: Bool
    var key: String
    var fileType: String
    
    func showPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        let result = panel.runModal()
        if result == .OK, let url = panel.urls.first {
            if fileType == "video" {
                if url.isVideoFile {
                    fileValues[key] = url
                } else {
                    isCancle = true
                    NSAlert.showError("请选择允许的视频/音频文件\n(webm, ogg, ogv)")
                }
            } else {
                if url.isImageFile {
                    fileValues[key] = url
                } else {
                    isCancle = true
                    NSAlert.showError("请选择允许的图片文件\n(jpg, jpeg, jfif, png, pnga, bmp, gif, svg, webp)")
                }
            }
            
        } else {
            isCancle = true
        }
        isPresented = false
    }
}

extension URL {
    // 校验是否为图片
    var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "jfif", "png", "pnga", "bmp", "gif", "svg", "webp"]
        return imageExtensions.contains(pathExtension.lowercased())
    }
    var isVideoFile: Bool {
        let videoExtensions = ["webm", "ogg", "ogv"]
        return videoExtensions.contains(pathExtension.lowercased())
    }
}

extension NSAlert {
    // 错误弹窗
    static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
