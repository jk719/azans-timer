import SwiftUI

struct CircularProgressView: View {
    let progress: Double          // Hour-based progress (for arc display)
    let relativeProgress: Double  // Relative progress (for colors/urgency)
    let timeString: String
    let totalSeconds: Int         // Total timer duration for segment calculation
    let activityIcon: String      // Current activity icon

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var tickPulse: CGFloat = 1.0

    init(progress: Double, relativeProgress: Double = 1.0, timeString: String = "", totalSeconds: Int = 0, activityIcon: String = "") {
        self.progress = progress
        self.relativeProgress = relativeProgress
        self.timeString = timeString
        self.totalSeconds = totalSeconds
        self.activityIcon = activityIcon
    }

    // Calculate segment positions (every 5 minutes for longer timers, quarters for shorter)
    private var segmentPositions: [Double] {
        guard totalSeconds > 0 else { return [] }

        var positions: [Double] = []

        if totalSeconds >= 600 { // 10+ minutes: show 5-minute segments
            let fiveMinutes = 300
            var current = fiveMinutes
            while current < totalSeconds {
                positions.append(Double(current) / Double(totalSeconds))
                current += fiveMinutes
            }
        } else if totalSeconds >= 120 { // 2-10 minutes: show quarters
            positions = [0.25, 0.5, 0.75]
        } else { // Under 2 minutes: show halfway only
            positions = [0.5]
        }

        return positions
    }

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 30)
                .blur(radius: 8)

            // Dark background circle for contrast
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 260, height: 260)

            // Background circle track
            Circle()
                .stroke(
                    Color.white.opacity(0.3),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .frame(width: 260, height: 260)

            // Time segment markers
            ForEach(Array(segmentPositions.enumerated()), id: \.offset) { _, position in
                SegmentMarker(position: position, isHalfway: position == 0.5)
            }

            // Remaining time arc (shrinks as time runs out) - bouncy animation
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 260, height: 260)
                .shadow(color: currentColor, radius: 8, x: 0, y: 0)
                .shadow(color: currentColor.opacity(0.6), radius: 20, x: 0, y: 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0), value: progress)

            // Center content
            VStack(spacing: 8) {
                // Activity icon
                if !activityIcon.isEmpty {
                    Image(systemName: activityIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(timeString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .scaleEffect(relativeProgress < 0.1 && relativeProgress > 0 ? pulseScale : 1.0)
            }

            // Urgency ring pulse when low time
            if relativeProgress > 0 && relativeProgress < 0.15 {
                Circle()
                    .stroke(currentColor.opacity(0.6), lineWidth: 4)
                    .scaleEffect(pulseScale * 1.1)
                    .opacity(2 - Double(pulseScale))
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: progress) { _ in
            // Pulse the marker dot each tick
            triggerTickPulse()
        }
        .onChange(of: relativeProgress) { _ in
            if relativeProgress < 0.15 && relativeProgress > 0 {
                startUrgentAnimations()
            }
        }
    }

    private func triggerTickPulse() {
        // Quick pulse animation
        tickPulse = 1.5
        withAnimation(.easeOut(duration: 0.15)) {
            tickPulse = 1.0
        }
    }

    private var progressColors: [Color] {
        // Kid-friendly, softer colors that match the app palette
        if relativeProgress > 0.5 {
            // Calm sky blue - plenty of time, relaxed
            return [Color(red: 0.45, green: 0.75, blue: 0.95), Color(red: 0.55, green: 0.8, blue: 0.95)]
        } else if relativeProgress > 0.25 {
            // Warm peach - getting there, gentle nudge
            return [Color(red: 1.0, green: 0.7, blue: 0.5), Color(red: 1.0, green: 0.6, blue: 0.45)]
        } else {
            // Soft coral-pink - almost done, exciting finish!
            return [Color(red: 1.0, green: 0.5, blue: 0.55), Color(red: 0.95, green: 0.55, blue: 0.6)]
        }
    }

    private var currentColor: Color {
        if relativeProgress > 0.5 {
            return Color(red: 0.5, green: 0.8, blue: 1.0) // Soft sky blue
        } else if relativeProgress > 0.25 {
            return Color(red: 1.0, green: 0.65, blue: 0.45) // Warm peach
        } else {
            return Color(red: 1.0, green: 0.5, blue: 0.55) // Soft coral
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }

    private func startUrgentAnimations() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.08
        }
    }
}

// Segment marker for visual time chunks
struct SegmentMarker: View {
    let position: Double
    let isHalfway: Bool

    var body: some View {
        let angle = (position * 360) - 90 // Convert to degrees, offset by -90 for top start
        let radius: CGFloat = 130 // Ring radius

        Circle()
            .fill(isHalfway ? Color.yellow : Color.white.opacity(0.6))
            .frame(width: isHalfway ? 10 : 6, height: isHalfway ? 10 : 6)
            .offset(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            )
            .shadow(color: isHalfway ? .yellow.opacity(0.5) : .clear, radius: 4)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.2, green: 0.1, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        CircularProgressView(progress: 0.65, timeString: "4:32", totalSeconds: 600, activityIcon: "book.fill")
            .frame(width: 280, height: 280)
    }
}
