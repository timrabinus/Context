//
//  AppIconPreview.swift
//  Context
//
//  Created to preview and generate app icon with sun symbol
//

import SwiftUI

struct AppIconView: View {
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Gradient background with sun colors
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.3),
                    Color(red: 1.0, green: 0.7, blue: 0.2),
                    Color(red: 1.0, green: 0.6, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Sun icon (same as Today tab)
            Image(systemName: "sun.max.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width * 0.6, height: size.height * 0.6)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.15))
    }
}

// Preview for regular app icon (400x240 @1x, 800x480 @2x)
struct RegularAppIconPreview: View {
    let scale: CGFloat
    
    var body: some View {
        AppIconView(size: CGSize(width: 400 * scale, height: 240 * scale))
            .previewLayout(.fixed(width: 400 * scale, height: 240 * scale))
    }
}

// Preview for App Store icon (1280x768 @1x, 2560x1536 @2x)
struct AppStoreIconPreview: View {
    let scale: CGFloat
    
    var body: some View {
        AppIconView(size: CGSize(width: 1280 * scale, height: 768 * scale))
            .previewLayout(.fixed(width: 1280 * scale, height: 768 * scale))
    }
}

// Preview at actual sizes for export
#Preview("Regular Icon @1x (400x240)") {
    RegularAppIconPreview(scale: 1.0)
}

#Preview("Regular Icon @2x (800x480)") {
    RegularAppIconPreview(scale: 2.0)
}

#Preview("App Store Icon @1x (1280x768)") {
    AppStoreIconPreview(scale: 1.0)
}

#Preview("App Store Icon @2x (2560x1536)") {
    AppStoreIconPreview(scale: 2.0)
}

// Combined preview (scaled down for viewing)
#Preview("All Icons (Preview)") {
    VStack(spacing: 20) {
        AppIconView(size: CGSize(width: 200, height: 120))
        
        AppIconView(size: CGSize(width: 320, height: 192))
    }
    .padding()
}
