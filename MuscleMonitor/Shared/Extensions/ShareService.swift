//
//  ShareService.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 29/09/2025.
//


import SwiftUI
import UIKit

enum ShareService {
    static let metaAppID = "734477179634103" // ← TON APP ID META
    private static let instaURL = URL(string: "instagram-stories://share?source_application=\(metaAppID)")!

    /// Partage en story Instagram une vue rendue en image (fond plein).
    static func shareInstagramStory(background view: some View,
                                    topColorHex: String = "#FFFFFF",
                                    bottomColorHex: String = "#FFFFFF") {
        let image = view.snapshot(scale: 1) // taille = frame fournie par la vue (cf. ShareCardView)
        guard let data = image.pngData() else { return }

        let items: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": data,
            "com.instagram.sharedSticker.backgroundTopColor": topColorHex,
            "com.instagram.sharedSticker.backgroundBottomColor": bottomColorHex,
            // Optionnels :
            // "com.instagram.sharedSticker.contentURL": "https://musclemonitor.io",
            // "com.instagram.sharedSticker.appID": metaAppID
        ]

        UIPasteboard.general.setItems([items], options: [.expirationDate: Date().addingTimeInterval(60)])

        if UIApplication.shared.canOpenURL(instaURL) {
            UIApplication.shared.open(instaURL, options: [:], completionHandler: nil)
        } else {
            // Fallback : share sheet iOS
            presentShareSheet(activityItems: [image])
        }
    }

    /// Variante avec un sticker par-dessus un fond dégradé (au lieu d’un background plein).
    static func shareInstagramStory(sticker view: some View,
                                    topColorHex: String = "#000000",
                                    bottomColorHex: String = "#222222") {
        let image = view.snapshot(scale: UIScreen.main.scale)
        guard let data = image.pngData() else { return }

        let items: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": data,
            "com.instagram.sharedSticker.backgroundTopColor": topColorHex,
            "com.instagram.sharedSticker.backgroundBottomColor": bottomColorHex,
        ]

        UIPasteboard.general.setItems([items], options: [.expirationDate: Date().addingTimeInterval(60)])

        if UIApplication.shared.canOpenURL(instaURL) {
            UIApplication.shared.open(instaURL, options: [:], completionHandler: nil)
        } else {
            presentShareSheet(activityItems: [image])
        }
    }

    private static func presentShareSheet(activityItems: [Any]) {
        let avc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(avc, animated: true)
        }
    }
}
