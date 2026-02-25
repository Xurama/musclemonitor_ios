import UIKit
import SwiftUI

struct InstagramStorySharing {
    static func canShareToStories() -> Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func share(sticker: UIImage, backgroundColor: UIColor? = nil, backgroundImage: UIImage? = nil, attributionURL: URL? = nil) {
        print("[IG] share(...) ENTER")
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.share(sticker: sticker, backgroundColor: backgroundColor, backgroundImage: backgroundImage, attributionURL: attributionURL) }
            return
        }
        
        let appID = ShareService.metaAppID
        let urlString = "instagram-stories://share?source_application=\(appID)"
        let urlScheme = URL(string: urlString)!

        guard UIApplication.shared.canOpenURL(urlScheme) else { return }

        let stickerData: Data? = sticker.pngData()
        let backgroundOnly = (backgroundImage != nil)

        if !backgroundOnly {
            // Sticker-only path requires sticker data
            guard let _ = stickerData else {
                print("[IG] ERROR: sticker.pngData() is nil and no backgroundImage provided — aborting")
                return
            }
        }

        var pasteboardItems: [String: Any] = [:]

        if backgroundOnly {
            if let bgImage = backgroundImage, let bgData = bgImage.pngData() {
                pasteboardItems["com.instagram.sharedSticker.backgroundImage"] = bgData
                pasteboardItems["com.instagram.sharedSticker.appID"] = appID
            } else {
                print("[IG] ERROR: backgroundImage provided but pngData() conversion failed — aborting")
                return
            }
        } else {
            if let data = stickerData {
                pasteboardItems["com.instagram.sharedSticker.stickerImage"] = data
            }
            if let bg = backgroundColor?.cgColor.components {
                // Build hex color (ignore alpha for Instagram color keys)
                let r = bg[0]
                let g = (bg.count > 1 ? bg[1] : r)
                let b = (bg.count > 2 ? bg[2] : r)
                let hex = String(format: "#%02lX%02lX%02lX", lroundf(Float(r*255)), lroundf(Float(g*255)), lroundf(Float(b*255)))
                pasteboardItems["com.instagram.sharedSticker.backgroundTopColor"] = hex
                pasteboardItems["com.instagram.sharedSticker.backgroundBottomColor"] = hex
            }
            if let link = attributionURL?.absoluteString {
                pasteboardItems["com.instagram.sharedSticker.contentURL"] = link
            }
            pasteboardItems["com.instagram.sharedSticker.appID"] = appID
        }

        print("[IG] Preparing pasteboard items: backgroundOnly=\(backgroundOnly), keys=\(pasteboardItems.keys), appID=\(appID)")

        if backgroundOnly {
            print("[IG] Using simple pasteboard assignment (items=\(pasteboardItems))")
            UIPasteboard.general.items = [pasteboardItems]
        } else {
            print("[IG] Using setItems with expiration")
            let options: [UIPasteboard.OptionsKey: Any] = [
                .expirationDate: Date().addingTimeInterval(300)
            ]
            UIPasteboard.general.setItems([pasteboardItems], options: options)
        }

        print("[IG] Pasteboard set. Scheduling openURL in 0.3s…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("[IG] Calling openURL instagram-stories://share …")
            UIApplication.shared.open(urlScheme, options: [:]) { success in
                print("[IG] openURL callback success=\(success)")
            }
        }
    }
}

extension View {
    func renderAsUIImage(scale: CGFloat = 3.0, size: CGSize? = nil) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        if let size = size { renderer.proposedSize = .init(size) }
        return renderer.uiImage
    }
}

// Note: Ensure Info.plist contains LSApplicationQueriesSchemes with "instagram-stories" so canOpenURL works.

