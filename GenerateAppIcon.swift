import SwiftUI
import UIKit

// This is a standalone script to generate the app icon
// Run this in a Swift Playground or as a macOS command-line tool

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Gradient background matching the app theme
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.3, blue: 0.3),
                    Color(red: 1.0, green: 0.5, blue: 0.2),
                    Color(red: 0.9, green: 0.4, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                // Clock icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 700, height: 700)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 650, height: 650)

                    // Clock face
                    ZStack {
                        // Hour markers
                        ForEach(0..<12) { index in
                            Rectangle()
                                .fill(Color(red: 1.0, green: 0.4, blue: 0.3))
                                .frame(width: 15, height: 80)
                                .offset(y: -240)
                                .rotationEffect(.degrees(Double(index) * 30))
                        }

                        // Center circle
                        Circle()
                            .fill(Color(red: 1.0, green: 0.4, blue: 0.3))
                            .frame(width: 80, height: 80)

                        // Hour hand (pointing at 10)
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .frame(width: 25, height: 200)
                            .offset(y: -80)
                            .rotationEffect(.degrees(-60))

                        // Minute hand (pointing at 2)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.3, green: 0.3, blue: 0.3))
                            .frame(width: 20, height: 280)
                            .offset(y: -120)
                            .rotationEffect(.degrees(60))
                    }
                }

                // "AT" text badge at bottom
                Text("AT")
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .offset(y: -50)
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

// Function to render and save the icon
@MainActor
func generateIcon() async {
    let view = AppIconView()
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0

    if let image = renderer.uiImage {
        if let data = image.pngData() {
            let fileManager = FileManager.default
            let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let fileURL = desktopURL.appendingPathComponent("AppIcon.png")

            try? data.write(to: fileURL)
            print("Icon saved to: \(fileURL.path)")
        }
    }
}

// For Playground usage:
#if canImport(PlaygroundSupport)
import PlaygroundSupport
PlaygroundPage.current.setLiveView(AppIconView())
#endif
