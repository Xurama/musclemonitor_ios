//
//  ViewInstagram.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 29/09/2025.
//

import SwiftUI
import UIKit

extension View {
    /// Rend la vue en UIImage aux dimensions exactes de son frame.
    func snapshot(scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        if let uiImage = renderer.uiImage {
            return uiImage
        }
        // Fallback très rare
        let host = UIHostingController(rootView: self)
        let target = host.view.intrinsicContentSize
        host.view.bounds = .init(origin: .zero, size: target)
        host.view.backgroundColor = .clear
        let r = UIGraphicsImageRenderer(size: target)
        return r.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}
