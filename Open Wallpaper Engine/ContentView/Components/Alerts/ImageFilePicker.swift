import SwiftUI
import AppKit
import UniformTypeIdentifiers
struct ImageFilePicker {
    @Binding var fileValues: [String: URL]
    @Binding var isPresented: Bool
    @Binding var isCancle: Bool
    var key: String
    
    private let imageTypes: [UTType] = [.image]
    
    func showPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = imageTypes
        let result = panel.runModal()
        if result == .OK, let url = panel.urls.first {
            if url.isImageFile {
                fileValues[key] = url
            } else {
                isCancle = true
                NSAlert.showError()
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
}

extension NSAlert {
    // 错误弹窗
    static func showError() {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = "请选择图片文件"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
