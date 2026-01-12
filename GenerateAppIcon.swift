//
//  GenerateAppIcon.swift
//  Context
//
//  Run this in Xcode or as a macOS command-line tool to generate app icon PNG files
//  Usage: In Xcode, add this as a new macOS Command Line Tool target, or run from terminal
//

import SwiftUI

#if canImport(AppKit)
import AppKit

@available(macOS 13.0, *)
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

@available(macOS 13.0, *)
func generateIcon(size: CGSize, scale: CGFloat, outputPath: String) {
    let view = AppIconView(size: size)
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    
    if let nsImage = renderer.nsImage {
        let outputSize = NSSize(width: size.width * scale, height: size.height * scale)
        let scaledImage = NSImage(size: outputSize)
        scaledImage.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: outputSize), from: .zero, operation: .sourceOver, fraction: 1.0)
        scaledImage.unlockFocus()
        
        if let tiffData = scaledImage.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: outputPath))
            print("Generated: \(outputPath)")
        }
    }
}

@available(macOS 13.0, *)
func generateAllIcons(outputDirectory: String) {
    let basePath = (outputDirectory as NSString).expandingTildeInPath
    
    // Regular App Icon: 400x240 @1x, 800x480 @2x
    generateIcon(size: CGSize(width: 400, height: 240), scale: 1.0, 
                 outputPath: "\(basePath)/icon-regular-1x.png")
    generateIcon(size: CGSize(width: 400, height: 240), scale: 2.0, 
                 outputPath: "\(basePath)/icon-regular-2x.png")
    
    // App Store Icon: 1280x768 @1x, 2560x1536 @2x
    generateIcon(size: CGSize(width: 1280, height: 768), scale: 1.0, 
                 outputPath: "\(basePath)/icon-appstore-1x.png")
    generateIcon(size: CGSize(width: 1280, height: 768), scale: 2.0, 
                 outputPath: "\(basePath)/icon-appstore-2x.png")
    
    print("\nAll icons generated in: \(basePath)")
    print("\nNow copy these files to the appropriate asset catalog locations:")
    print("- icon-regular-1x.png and icon-regular-2x.png → App Icon.imagestack/Front.imagestacklayer/Content.imageset/")
    print("- icon-appstore-1x.png and icon-appstore-2x.png → App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/")
}

// Note: To run this as a script, create a macOS Command Line Tool target in Xcode
// and call: generateAllIcons(outputDirectory: "~/Desktop/AppIcons")

#endif
