import SwiftUI
import AppKit // macOS 替代 UIKit 的框架
import UniformTypeIdentifiers // 跨平台 UTType 仍可用

// MARK: macOS 图片文件选择器（封装 NSOpenPanel）
struct ImageFilePicker {
    @Binding var fileValues: [String: URL]
    @Binding var isPresented: Bool
    @Binding var isCancle: Bool
    var key: String
    
    // 筛选仅图片类型（跨平台 UTType，macOS 兼容）
    private let imageTypes: [UTType] = [.image]
    
    // 弹出文件选择面板
    func showPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false // 仅选单张
        panel.canChooseDirectories = false // 不选文件夹
        panel.canCreateDirectories = false
        panel.allowedContentTypes = imageTypes // 核心：筛选图片
        let result = panel.runModal()
        // 弹出面板并处理选择结果
        if result == .OK, let url = panel.urls.first {
            // 二次校验图片类型（增强安全性）
            if url.isImageFile {
                fileValues[key] = url
            } else {
                isCancle = true
                NSAlert.showError(message: "请选择图片文件")
            }
        } else {
            isCancle = true
        }
        isPresented = false
    }
}

// MARK: 工具扩展（macOS 适配）
extension URL {
    // 校验是否为图片文件（跨平台通用）
    var isImageFile: Bool {
        let imageExtensions = ["jpg", "jpeg", "jfif", "png", "pnga", "bmp", "gif", "svg", "webp"]
        return imageExtensions.contains(pathExtension.lowercased())
    }
}

extension NSAlert {
    // 快速展示错误提示（macOS 弹窗）
    static func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
