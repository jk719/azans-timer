import SwiftUI

struct PresetButton: View {
    let title: String
    let emoji: String
    let minutes: Int?
    let color: Color
    let action: () -> Void
    var onTimeTap: (() -> Void)? = nil

    @State private var isPressed = false
    @State private var isHovering = false
    @State private var sparkleOpacity = 0.0

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                sparkleOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    sparkleOpacity = 0.0
                }
            }

            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.6), radius: isPressed ? 5 : 20, x: 0, y: isPressed ? 2 : 10)

                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )

                if sparkleOpacity > 0 {
                    ZStack {
                        ForEach(0..<8) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .offset(
                                    x: cos(Double(index) * .pi / 4) * 60,
                                    y: sin(Double(index) * .pi / 4) * 60
                                )
                                .opacity(sparkleOpacity)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text(emoji)
                        .font(.system(size: 50))
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                        .rotationEffect(.degrees(isPressed ? 5 : 0))

                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)

                    if let minutes = minutes {
                        Button(action: {
                            if let onTimeTap = onTimeTap {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                onTimeTap()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("\(minutes) min")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .minimumScaleFactor(0.6)
                            }
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .rotationEffect(.degrees(isPressed ? 2 : 0))
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = newValue
                }
            }
    }
}

struct RadialPresetButton: View {
    let title: String
    let icon: String
    let minutes: Int
    let color: Color
    let action: () -> Void
    var onTimeTap: (() -> Void)? = nil
    var showTutorialHighlight: Bool = false      // Highlights clock badge
    var showMainButtonHighlight: Bool = false    // Highlights entire button

    @State private var isPressed = false
    @State private var pulseAnimation = false
    @State private var mainPulseAnimation = false

    var body: some View {
        VStack(spacing: 6) {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                action()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: color.opacity(0.6), radius: isPressed ? 5 : 12, x: 0, y: isPressed ? 2 : 6)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90, height: 90)

                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .scaleEffect(isPressed ? 0.85 : 1.0)

                        Text(title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .background(
                    Group {
                        if showMainButtonHighlight {
                            Circle()
                                .stroke(Color.purple, lineWidth: 4)
                                .shadow(color: .purple, radius: 12)
                                .frame(width: 90, height: 90)
                                .scaleEffect(mainPulseAnimation ? 1.3 : 1.15)
                        }
                    }
                )
            }
            .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
            .zIndex(showMainButtonHighlight ? 100 : 0)

            // Time badge below the circle
            Button(action: {
                if let onTimeTap = onTimeTap {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onTimeTap()
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(minutes)m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Image(systemName: "pencil")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.8))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .background(
                    Group {
                        if showTutorialHighlight {
                            Capsule()
                                .stroke(Color.cyan, lineWidth: 3)
                                .shadow(color: .cyan, radius: 10)
                                .scaleEffect(pulseAnimation ? 1.3 : 1.15)
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(showTutorialHighlight ? 100 : 0)
        }
        .onAppear {
            if showTutorialHighlight {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            if showMainButtonHighlight {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    mainPulseAnimation = true
                }
            }
        }
        .onChange(of: showTutorialHighlight) { isHighlighted in
            if isHighlighted {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
        .onChange(of: showMainButtonHighlight) { isHighlighted in
            if isHighlighted {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    mainPulseAnimation = true
                }
            } else {
                mainPulseAnimation = false
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        PresetButton(
            title: "Reading",
            emoji: "📚",
            minutes: 20,
            color: Color(red: 0.2, green: 0.8, blue: 0.6)
        ) {
            print("Reading tapped")
        }
        .frame(width: 160)
        .padding()
    }
}
