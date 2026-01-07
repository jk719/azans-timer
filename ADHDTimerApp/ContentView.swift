import SwiftUI

// Tutorial step enum - defined outside ContentView so other views can access it
enum TutorialStep: Int {
    case startTimer = 1      // Tap activity to start
    case clockBadge = 2      // Tap clock badge to customize
    case customTimer = 3     // Tap center custom button
    case starsBadge = 4      // Tap stars badge
    case streakBadge = 5     // Tap streak badge (conditional)
    case doneButton = 6      // Tap "I'm Done!" button
    case historyButton = 7   // Tap history button
    case settingsButton = 8  // Tap settings button
    case pinSetupRow = 9     // Inside Settings - highlight PIN setup
}

enum TutorialMessagePosition {
    case top, bottom
}

enum ActivityType {
    case ipad, reading, shower, homework
}

// Bouncing hand pointer for tutorial - modern, clean UX
struct TutorialHandPointer: View {
    @State private var bounce = false
    var direction: HandDirection = .down

    enum HandDirection {
        case down, up, left, right

        var iconName: String {
            switch self {
            case .down: return "hand.point.down.fill"
            case .up: return "hand.point.up.fill"
            case .left: return "hand.point.left.fill"
            case .right: return "hand.point.right.fill"
            }
        }

        var bounceOffset: (x: CGFloat, y: CGFloat) {
            switch self {
            case .down: return (0, 8)
            case .up: return (0, -8)
            case .left: return (-8, 0)
            case .right: return (8, 0)
            }
        }
    }

    var body: some View {
        Image(systemName: direction.iconName)
            .font(.system(size: 36, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            .shadow(color: .yellow.opacity(0.6), radius: 8)
            .offset(
                x: bounce ? direction.bounceOffset.x : -direction.bounceOffset.x,
                y: bounce ? direction.bounceOffset.y : -direction.bounceOffset.y
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    bounce = true
                }
            }
    }
}

// Triangle shape for tooltip caret
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// Floating tooltip bubble for tutorial
struct TutorialTooltip: View {
    let text: String
    var caretPosition: CaretPosition = .bottom

    enum CaretPosition {
        case top, bottom
    }

    var body: some View {
        VStack(spacing: 0) {
            if caretPosition == .top {
                Triangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 14, height: 8)
                    .rotationEffect(.degrees(180))
            }

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.85))
                )

            if caretPosition == .bottom {
                Triangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 14, height: 8)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var settings = TimerSettings.shared
    @State private var customMinutes: Int = 5
    @State private var customActivityName: String = ""
    @State private var isAnimating = false
    @State private var floatingOffset: CGFloat = 0
    @State private var showingEditSheet = false
    @State private var editingActivity: ActivityType?
    @State private var editingMinutes: Int = 10
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var pauseDisplayTimer: Timer? = nil
    @State private var pauseDisplayUpdate: Bool = false
    @State private var showingPINSetup = false
    @State private var showingPINSetupFromPrompt = false  // PIN setup triggered from completion prompt
    @State private var enteredPIN: String = ""
    @State private var showingOnboarding = false
    @State private var showingCancelConfirm = false

    // Interactive tutorial state
    @State private var activeTutorialStep: TutorialStep? = nil
    @State private var tutorialPulse: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: viewModel.backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5), value: viewModel.progress)

            VStack(spacing: 0) {
                // Top bar with settings and history
                HStack {
                    Button(action: {
                        if activeTutorialStep == .historyButton {
                            // Tutorial mode - advance to settings button
                            settings.hasSeenHistoryTip = true
                            withAnimation {
                                activeTutorialStep = .settingsButton
                            }
                        } else if activeTutorialStep == nil {
                            // Normal mode
                            showingHistory = true
                        }
                        // During other tutorial steps, do nothing
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .background(
                        Group {
                            if activeTutorialStep == .historyButton {
                                Circle()
                                    .stroke(Color.purple, lineWidth: 5)
                                    .shadow(color: .purple, radius: 16)
                                    .shadow(color: .purple.opacity(0.8), radius: 24)
                                    .scaleEffect(tutorialPulse ? 1.3 : 1.15)
                            }
                        }
                    )
                    .zIndex(activeTutorialStep == .historyButton ? 100 : 0)
                    .overlay(alignment: .bottom) {
                        if activeTutorialStep == .historyButton {
                            VStack(spacing: 4) {
                                TutorialTooltip(text: "See progress", caretPosition: .bottom)
                                TutorialHandPointer(direction: .up)
                            }
                            .offset(y: 65)
                        }
                    }

                    Spacer()

                    // Stars badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(settings.totalStars)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                    .background(
                        Group {
                            if activeTutorialStep == .starsBadge {
                                Capsule()
                                    .stroke(Color.yellow, lineWidth: 5)
                                    .shadow(color: .yellow, radius: 16)
                                    .shadow(color: .yellow.opacity(0.8), radius: 24)
                                    .scaleEffect(tutorialPulse ? 1.25 : 1.1)
                            }
                        }
                    )
                    .onTapGesture {
                        if activeTutorialStep == .starsBadge {
                            withAnimation {
                                settings.hasSeenStarsTip = true
                                // If user has a streak, go to streak badge, otherwise go to done button
                                if settings.currentStreak > 0 {
                                    activeTutorialStep = .streakBadge
                                } else {
                                    activeTutorialStep = .doneButton
                                }
                            }
                        }
                    }
                    .zIndex(activeTutorialStep == .starsBadge ? 100 : 0)
                    .overlay(alignment: .bottom) {
                        if activeTutorialStep == .starsBadge {
                            VStack(spacing: 4) {
                                TutorialTooltip(text: "Your stars!", caretPosition: .bottom)
                                TutorialHandPointer(direction: .up)
                            }
                            .offset(y: 60)
                        }
                    }

                    // Streak badge
                    if settings.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(settings.currentStreak)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                        .background(
                            Group {
                                if activeTutorialStep == .streakBadge {
                                    Capsule()
                                        .stroke(Color.orange, lineWidth: 5)
                                        .shadow(color: .orange, radius: 16)
                                        .shadow(color: .orange.opacity(0.8), radius: 24)
                                        .scaleEffect(tutorialPulse ? 1.25 : 1.1)
                                }
                            }
                        )
                        .onTapGesture {
                            if activeTutorialStep == .streakBadge {
                                withAnimation {
                                    activeTutorialStep = .doneButton
                                }
                            }
                        }
                        .zIndex(activeTutorialStep == .streakBadge ? 100 : 0)
                        .overlay(alignment: .bottom) {
                            if activeTutorialStep == .streakBadge {
                                VStack(spacing: 4) {
                                    TutorialTooltip(text: "Daily streak!", caretPosition: .bottom)
                                    TutorialHandPointer(direction: .up)
                                }
                                .offset(y: 60)
                            }
                        }
                    }

                    Spacer()

                    // Tutorial button (icon for compact screens)
                    Button(action: {
                        guard activeTutorialStep == nil else { return }
                        settings.resetTutorials()
                        withAnimation(.spring()) {
                            activeTutorialStep = .startTimer
                        }
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .opacity(activeTutorialStep != nil ? 0.5 : 1.0)
                    .disabled(activeTutorialStep != nil)

                    Button(action: {
                        // Tutorial step 8: Settings button
                        if activeTutorialStep == .settingsButton {
                            showingSettings = true
                            withAnimation {
                                activeTutorialStep = .pinSetupRow
                            }
                            return
                        }
                        // Block during other tutorial steps
                        guard activeTutorialStep == nil else { return }
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .background(
                        Group {
                            if activeTutorialStep == .settingsButton {
                                Circle()
                                    .stroke(Color.gray, lineWidth: 5)
                                    .shadow(color: .gray, radius: 16)
                                    .shadow(color: .white.opacity(0.5), radius: 24)
                                    .scaleEffect(tutorialPulse ? 1.3 : 1.15)
                            }
                        }
                    )
                    .zIndex(activeTutorialStep == .settingsButton ? 100 : 0)
                    .overlay(alignment: .bottom) {
                        if activeTutorialStep == .settingsButton {
                            VStack(spacing: 4) {
                                TutorialTooltip(text: "Settings", caretPosition: .bottom)
                                TutorialHandPointer(direction: .up)
                            }
                            .offset(y: 65)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.timeRemaining > 0 || viewModel.totalTime > 0 {
                            timerDisplay
                                .padding(.top, 20)
                        } else {
                            welcomeText
                                .padding(.top, 10)
                        }

                        // Show presetButtons when idle OR during tutorial steps that need it
                        let tutorialNeedsPresetButtons = activeTutorialStep == .startTimer ||
                                                          activeTutorialStep == .clockBadge ||
                                                          activeTutorialStep == .customTimer
                        if (!viewModel.isRunning && viewModel.timeRemaining == 0 && viewModel.totalTime == 0) || tutorialNeedsPresetButtons {
                            presetButtons
                                .padding(.top, 10)
                                .padding(.bottom, 60)
                        }

                        // Show controlButtons when timer running OR during doneButton tutorial step
                        if viewModel.isRunning || viewModel.timeRemaining > 0 || activeTutorialStep == .doneButton {
                            controlButtons
                                .padding(.top, 20)
                                .padding(.bottom, 40)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            // PIN verification overlay
            if viewModel.awaitingVerification {
                PINEntryView(
                    enteredPIN: $enteredPIN,
                    onVerify: { pin in
                        return viewModel.verifyPIN(pin)
                    },
                    onSuccess: {
                        withAnimation {
                            viewModel.confirmVerification()
                        }
                        enteredPIN = ""
                    }
                )
            }

            // Quality rating overlay (shown after PIN verification)
            if viewModel.showQualityRating {
                QualityRatingView(
                    streakMultiplier: settings.streakMultiplier,
                    onRatingSelected: { rating in
                        withAnimation {
                            viewModel.confirmVerificationWithRating(rating)
                        }
                    }
                )
            }

            // PIN setup prompt overlay (shown after task completion if no PIN set)
            if viewModel.showPINSetupPrompt {
                PINSetupPromptView(
                    onSetupNow: {
                        showingPINSetupFromPrompt = true
                    },
                    onMaybeLater: {
                        withAnimation {
                            viewModel.skipPINSetup()
                        }
                    },
                    onDontAskAgain: {
                        withAnimation {
                            settings.skipPINSetupPermanently = true
                            viewModel.skipPINSetup()
                        }
                    }
                )
            }

            // Skip Tutorial button - subtle, always at bottom during tutorial
            if activeTutorialStep != nil && activeTutorialStep != .pinSetupRow {
                VStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            activeTutorialStep = nil
                        }
                    }) {
                        Text("Skip")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $viewModel.showCustomPicker) {
            customTimerPicker
        }
        .sheet(isPresented: $showingEditSheet) {
            editTimerSheet
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showingHistory) {
            historySheet
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView(isPresented: $showingPINSetup)
        }
        .sheet(isPresented: $showingPINSetupFromPrompt) {
            PINSetupView(isPresented: $showingPINSetupFromPrompt, onSuccess: {
                // PIN was set up from prompt - now require verification
                viewModel.completePINSetup()
            })
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding)
        }
        .alert("Stop Timer?", isPresented: $showingCancelConfirm) {
            Button("Stop", role: .destructive) { viewModel.resetTimer() }
            Button("Keep Going", role: .cancel) { }
        } message: {
            Text("Your progress won't be saved.")
        }
        .onAppear {
            // Show onboarding if child name not set
            if !settings.hasCompletedOnboarding {
                showingOnboarding = true
            }
            // Start pulsing animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                tutorialPulse = true
            }
        }
        .onChange(of: showingOnboarding) { wasShowing in
            // Trigger comprehensive tutorial after onboarding completes
            if wasShowing && !showingOnboarding && settings.hasCompletedOnboarding && !settings.hasSeenClockBadgeTip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.spring()) {
                        activeTutorialStep = .startTimer
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Update pause display
            if viewModel.pausedAt != nil {
                pauseDisplayUpdate.toggle()
            }
        }
    }

    // MARK: - Tutorial Helper Functions

    private func tutorialInstruction(for step: TutorialStep) -> String {
        switch step {
        case .startTimer: return "Tap iPad to start a timer!"
        case .clockBadge: return "Tap the clock to customize time!"
        case .customTimer: return "Create your own custom timer!"
        case .starsBadge: return "Earn stars by completing tasks!"
        case .streakBadge: return "Keep your daily streak going!"
        case .doneButton: return "Tap when you finish early!"
        case .historyButton: return "See all your progress here!"
        case .settingsButton: return "Open settings to customize!"
        case .pinSetupRow: return "Ask a parent to set up a PIN!\nThey'll verify tasks and award bonus stars!"
        }
    }

    private func tutorialHighlightColor(for step: TutorialStep) -> Color {
        switch step {
        case .startTimer: return .purple
        case .clockBadge: return .cyan
        case .customTimer: return .pink
        case .starsBadge: return .yellow
        case .streakBadge: return .orange
        case .doneButton: return .green
        case .historyButton: return .purple
        case .settingsButton: return .gray
        case .pinSetupRow: return .orange
        }
    }

    private func tutorialMessagePosition(for step: TutorialStep) -> TutorialMessagePosition {
        switch step {
        case .startTimer, .clockBadge, .customTimer, .doneButton:
            return .top      // Element in middle/bottom → message at top
        case .starsBadge, .streakBadge, .historyButton, .settingsButton, .pinSetupRow:
            return .bottom   // Element at top → message at bottom
        }
    }

    private var welcomeText: some View {
        VStack(spacing: 15) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160 + CGFloat(index * 30), height: 160 + CGFloat(index * 30))
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }

                VStack(spacing: 8) {
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 70, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .rotationEffect(.degrees(isAnimating ? 8 : -8))
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .offset(y: floatingOffset)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: floatingOffset
                        )

                    Text("\(settings.childName)'s Timer")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .padding(.horizontal, 20)
                }
            }
            .frame(height: 220)

            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: floatingOffset * 0.5)
                    .animation(
                        Animation.easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true),
                        value: floatingOffset
                    )

                Text("Pick Your Activity!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.white)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: floatingOffset * 0.5)
                    .animation(
                        Animation.easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true),
                        value: floatingOffset
                    )
            }
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .onAppear {
            isAnimating = true
            floatingOffset = -10
        }
    }

    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Activity label
            if !viewModel.currentActivity.isEmpty && viewModel.timeRemaining > 0 {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.currentActivityIcon)
                        .font(.system(size: 18, weight: .semibold))
                    Text(viewModel.currentActivity)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }

            ZStack {
                // Celebration burst on completion
                if viewModel.timeRemaining == 0 && viewModel.totalTime > 0 {
                    ForEach(0..<12) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yellow)
                            .offset(
                                x: cos(Double(index) * .pi / 6) * 140,
                                y: sin(Double(index) * .pi / 6) * 140
                            )
                            .scaleEffect(isAnimating ? 1.5 : 0.0)
                            .opacity(isAnimating ? 0.0 : 1.0)
                            .animation(
                                Animation.easeOut(duration: 1.5)
                                    .delay(Double(index) * 0.05),
                                value: isAnimating
                            )
                    }
                }

                // Main timer - use relativeProgress so full circle = your timer duration
                CircularProgressView(
                    progress: viewModel.relativeProgress,
                    relativeProgress: viewModel.relativeProgress,
                    timeString: viewModel.timeRemaining == 0 ? "" : viewModel.timeRemainingFormatted,
                    totalSeconds: viewModel.totalTime,
                    activityIcon: viewModel.timeRemaining > 0 ? viewModel.currentActivityIcon : ""
                )
                .frame(width: 320, height: 320)

                // Persistent PAUSED indicator
                if viewModel.pausedAt != nil && !viewModel.isRunning && viewModel.timeRemaining > 0 {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 16))
                            Text("PAUSED")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                    .frame(width: 320, height: 320)
                }

                // Completion overlay - shown when timer finished
                if viewModel.timeRemaining == 0 && viewModel.totalTime > 0 && !viewModel.awaitingVerification && !viewModel.showQualityRating {
                    ZStack {
                        // Floating confetti decorations
                        ForEach(0..<8, id: \.self) { index in
                            Image(systemName: ["star.fill", "heart.fill", "sparkle", "moon.stars.fill"][index % 4])
                                .font(.system(size: CGFloat.random(in: 16...28)))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            [Color.yellow, Color.orange],
                                            [Color.pink, Color.red],
                                            [Color.cyan, Color.blue],
                                            [Color.green, Color.mint]
                                        ][index % 4],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .offset(
                                    x: CGFloat([-120, 120, -100, 100, -80, 80, -60, 60][index]),
                                    y: CGFloat([-140, -120, -60, -40, 40, 60, 120, 140][index])
                                )
                                .scaleEffect(isAnimating ? 1.2 : 0.8)
                                .rotationEffect(.degrees(isAnimating ? Double(index * 45) : Double(index * -45)))
                                .opacity(isAnimating ? 0.4 : 0.2)
                                .animation(
                                    Animation.easeInOut(duration: Double.random(in: 1.0...2.0))
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.1),
                                    value: isAnimating
                                )
                        }

                        VStack(spacing: 20) {
                            // Trophy/celebration header
                            ZStack {
                                // Glow circle
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.yellow.opacity(0.4), Color.clear],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                    .scaleEffect(isAnimating ? 1.2 : 0.9)
                                    .animation(
                                        Animation.easeInOut(duration: 1.0)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )

                                // Trophy icon
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 70, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.65, blue: 0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                                    .scaleEffect(isAnimating ? 1.1 : 0.95)
                                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )
                            }

                            Text("Amazing!")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                            // Show completion message in a card
                            if !viewModel.completionMessage.isEmpty {
                                Text(viewModel.completionMessage)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }

                            // Stars earned celebration (only show if stars were earned via rating)
                            if viewModel.lastEarnedStars > 0 && viewModel.isVerified {
                                HStack(spacing: 10) {
                                    Text("+\(viewModel.lastEarnedStars)")
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundColor(.yellow)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.yellow)
                                        .rotationEffect(.degrees(isAnimating ? 15 : -15))
                                        .animation(
                                            Animation.easeInOut(duration: 0.4)
                                                .repeatForever(autoreverses: true),
                                            value: isAnimating
                                        )
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.yellow, .orange],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        )
                                )
                                .shadow(color: .yellow.opacity(0.4), radius: 12, x: 0, y: 6)
                                .scaleEffect(isAnimating ? 1.08 : 0.95)
                                .animation(
                                    Animation.easeInOut(duration: 0.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                            }

                            // "New Timer" button
                            Button(action: {
                                viewModel.resetTimer()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22, weight: .bold))
                                    Text("New Timer")
                                        .font(.system(size: 20, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color.purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                )
                                .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                            }
                            .scaleEffect(isAnimating ? 1.02 : 0.98)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.85),
                                            Color.black.opacity(0.75)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
            }

            // Encouraging message
            if viewModel.timeRemaining > 0 && !viewModel.encouragingMessage.isEmpty {
                Text(viewModel.encouragingMessage)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .animation(.easeInOut, value: viewModel.encouragingMessage)
            }

            // Pause duration display
            if let pauseDuration = viewModel.pauseDurationFormatted {
                let _ = pauseDisplayUpdate // Force refresh
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Paused for \(pauseDuration)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.yellow.opacity(0.2)))
            }

            // Urgency indicator
            if viewModel.timeRemaining <= 60 && viewModel.timeRemaining > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Almost done!")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.25))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                        )
                )
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
    }

    private var presetButtons: some View {
        // Bright & Playful colors for kids
        let presets: [(title: String, icon: String, minutes: Int, color: Color, activity: ActivityType)] = [
            ("iPad", "ipad", settings.ipadTime, Color(red: 0.6, green: 0.4, blue: 1.0), .ipad),           // Vibrant purple
            ("Reading", "book.fill", settings.readingTime, Color(red: 0.2, green: 0.8, blue: 0.85), .reading),  // Bright turquoise
            ("Shower", "drop.fill", settings.showerTime, Color(red: 0.35, green: 0.65, blue: 1.0), .shower),    // Bright blue
            ("Homework", "pencil.and.ruler.fill", settings.homeworkTime, Color(red: 1.0, green: 0.6, blue: 0.25), .homework) // Sunny orange
        ]

        let radius: CGFloat = 120

        return ZStack {
            // Center custom button
            Button(action: {
                // Tutorial step 3: Custom timer button - advance AND start timer
                if activeTutorialStep == .customTimer {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    withAnimation {
                        activeTutorialStep = .starsBadge
                    }
                    // NOW start a demo timer for the remaining tutorial steps
                    viewModel.startTimer(minutes: settings.ipadTime, activity: "iPad", activityIcon: "ipad")
                    return
                }
                // Block during other tutorial steps
                guard activeTutorialStep == nil else { return }
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                viewModel.showCustomPicker = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 0.9, green: 0.35, blue: 0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.5), radius: 15, x: 0, y: 8)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)

                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                        Text("Custom")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .background(
                    Group {
                        if activeTutorialStep == .customTimer {
                            Circle()
                                .stroke(Color.pink, lineWidth: 5)
                                .shadow(color: .pink, radius: 16)
                                .shadow(color: .pink.opacity(0.8), radius: 24)
                                .frame(width: 100, height: 100)
                                .scaleEffect(tutorialPulse ? 1.3 : 1.15)
                        }
                    }
                )
            }
            .zIndex(activeTutorialStep == .customTimer ? 100 : 0)
            .overlay(alignment: .top) {
                if activeTutorialStep == .customTimer {
                    VStack(spacing: 4) {
                        TutorialHandPointer(direction: .down)
                        TutorialTooltip(text: "Make your own!", caretPosition: .top)
                    }
                    .offset(y: -75)
                }
            }

            // Radial preset buttons
            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                let angle = (Double(index) * 90 - 45) * .pi / 180

                RadialPresetButton(
                    title: preset.title,
                    icon: preset.icon,
                    minutes: preset.minutes,
                    color: preset.color,
                    action: {
                        // Tutorial step 1: Just advance (don't start timer yet)
                        if activeTutorialStep == .startTimer && index == 0 {
                            // DON'T start timer here - wait until step 3 completes
                            withAnimation {
                                activeTutorialStep = .clockBadge
                            }
                            return
                        }
                        // Block other buttons during tutorial
                        guard activeTutorialStep == nil else { return }
                        viewModel.startTimer(minutes: preset.minutes, activity: preset.title, activityIcon: preset.icon)
                    },
                    onTimeTap: {
                        if activeTutorialStep == .clockBadge && index == 0 {
                            // Tutorial mode - only first button (iPad) responds
                            settings.hasSeenClockBadgeTip = true
                            // Briefly show edit sheet then advance
                            showingEditSheet = true
                            editingActivity = preset.activity
                            editingMinutes = max(5, ((preset.minutes + 2) / 5) * 5)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showingEditSheet = false
                                withAnimation {
                                    activeTutorialStep = .customTimer
                                }
                            }
                        } else if activeTutorialStep == nil {
                            // Normal mode - all clock badges work
                            editingActivity = preset.activity
                            editingMinutes = max(5, ((preset.minutes + 2) / 5) * 5)
                            showingEditSheet = true
                        }
                        // During tutorial, non-highlighted clock badges do nothing
                    },
                    showTutorialHighlight: activeTutorialStep == .clockBadge && index == 0,  // Highlight clock badge
                    showMainButtonHighlight: activeTutorialStep == .startTimer && index == 0  // Highlight main button
                )
                .offset(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius
                )
                .zIndex((activeTutorialStep == .clockBadge || activeTutorialStep == .startTimer) && index == 0 ? 100 : 0)
            }
        }
        .frame(height: 340)
        .padding(.horizontal)
    }

    private var controlButtons: some View {
        HStack(spacing: 24) {
            // Pause/Play button
            Button(action: {
                // Block during tutorial
                guard activeTutorialStep == nil else { return }
                if viewModel.isRunning {
                    viewModel.pauseTimer()
                } else if viewModel.timeRemaining > 0 {
                    viewModel.resumeTimer()
                }
            }) {
                Image(systemName: viewModel.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 55))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }

            // "I'm Done!" button - for early completion
            Button(action: {
                // Tutorial step 6: Done button
                if activeTutorialStep == .doneButton {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    // Cancel timer without saving and advance to history
                    viewModel.resetTimer()
                    withAnimation {
                        activeTutorialStep = .historyButton
                    }
                    return
                }
                // Block during other tutorial steps
                guard activeTutorialStep == nil else { return }
                viewModel.finishEarly()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.75, blue: 0.25), Color(red: 0.95, green: 0.55, blue: 0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.orange.opacity(0.5), radius: 10, x: 0, y: 5)
                    Text("Done!")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .background(
                    Group {
                        if activeTutorialStep == .doneButton {
                            Circle()
                                .stroke(Color.green, lineWidth: 5)
                                .shadow(color: .green, radius: 16)
                                .shadow(color: .green.opacity(0.8), radius: 24)
                                .frame(width: 55, height: 55)
                                .scaleEffect(tutorialPulse ? 1.4 : 1.2)
                        }
                    }
                )
            }
            .zIndex(activeTutorialStep == .doneButton ? 100 : 0)
            .overlay(alignment: .top) {
                if activeTutorialStep == .doneButton {
                    VStack(spacing: 4) {
                        TutorialHandPointer(direction: .down)
                        TutorialTooltip(text: "Finish early", caretPosition: .top)
                    }
                    .offset(y: -70)
                }
            }

            // Stop/Cancel button
            Button(action: {
                // Block during tutorial
                guard activeTutorialStep == nil else { return }
                showingCancelConfirm = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 55))
                    .foregroundColor(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
    }

    private var customTimerPicker: some View {
        CustomTimerPickerView(
            customActivityName: $customActivityName,
            customMinutes: $customMinutes,
            onStart: { activityName in
                viewModel.showCustomPicker = false
                viewModel.startTimer(minutes: customMinutes, activity: activityName, activityIcon: "star.fill")
                customActivityName = ""
            },
            onCancel: {
                viewModel.showCustomPicker = false
                customActivityName = ""
            }
        )
    }

    private var editTimerSheet: some View {
        EditTimerSheetView(
            editingActivity: editingActivity,
            editingMinutes: $editingMinutes,
            activityName: editingActivity.map { activityName($0) } ?? "Timer",
            activityIcon: editingActivity.map { activityIcon($0) } ?? "clock.fill",
            onSave: {
                saveEditedTime()
                showingEditSheet = false
            },
            onCancel: {
                showingEditSheet = false
            }
        )
    }

    // Milestone banner that appears at the bottom
    private var milestoneBanner: some View {
        let emoji = milestoneEmoji(for: viewModel.currentMilestone)

        return HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 32))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text(viewModel.milestoneMessage)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text(emoji)
                .font(.system(size: 32))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(0.2),
                    value: isAnimating
                )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.5, green: 0.35, blue: 0.85), Color(red: 0.4, green: 0.3, blue: 0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                )
        )
        .shadow(color: .purple.opacity(0.4), radius: 15, x: 0, y: 8)
        .scaleEffect(isAnimating ? 1.02 : 0.98)
        .animation(
            Animation.easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
            value: isAnimating
        )
    }

    private func milestoneEmoji(for milestone: MilestoneType?) -> String {
        switch milestone {
        case .halfway: return "🎯"
        case .fiveMinutes: return "⚡️"
        case .twoMinutes: return "🔥"
        case .oneMinute: return "🚀"
        case .thirtySeconds: return "💨"
        case .custom: return "⭐️"
        case .none: return "🔔"
        }
    }

    // Settings sheet
    private var settingsSheet: some View {
        SettingsSheetView(
            tickSoundEnabled: $settings.tickSoundEnabled,
            childName: $settings.childName,
            isVerificationEnabled: settings.isVerificationEnabled,
            activeTutorialStep: $activeTutorialStep,
            tutorialPulse: tutorialPulse,
            onPINSetupTap: {
                // If in tutorial, complete it
                if activeTutorialStep == .pinSetupRow {
                    withAnimation {
                        activeTutorialStep = nil
                    }
                }
                showingSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingPINSetup = true
                }
            },
            onSkipTutorial: {
                withAnimation {
                    activeTutorialStep = nil
                }
                showingSettings = false
            },
            onDone: {
                showingSettings = false
            }
        )
    }

    // History sheet
    private var historySheet: some View {
        HistorySheetView(
            todayCount: settings.todaySessionCount,
            streak: settings.currentStreak,
            totalCount: settings.sessionHistory.count,
            sessions: Array(settings.sessionHistory.prefix(20)),
            onDone: {
                showingHistory = false
            }
        )
    }

    private func activityName(_ activity: ActivityType) -> String {
        switch activity {
        case .ipad: return "iPad Time"
        case .reading: return "Reading"
        case .shower: return "Shower"
        case .homework: return "Homework"
        }
    }

    private func activityIcon(_ activity: ActivityType) -> String {
        switch activity {
        case .ipad: return "ipad"
        case .reading: return "book.fill"
        case .shower: return "drop.fill"
        case .homework: return "pencil.and.ruler.fill"
        }
    }

    private func saveEditedTime() {
        guard let activity = editingActivity else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        switch activity {
        case .ipad:
            settings.ipadTime = editingMinutes
        case .reading:
            settings.readingTime = editingMinutes
        case .shower:
            settings.showerTime = editingMinutes
        case .homework:
            settings.homeworkTime = editingMinutes
        }
    }
}

// Helper views for history
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.1)))
    }
}

struct SessionRow: View {
    let session: TimerSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.activityIcon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.activity)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(formatDate(session.completedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(session.allocatedTime))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                // Show if finished early
                if session.finishedEarly {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("done in \(formatDuration(session.actualTime))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(seconds) sec"
        }
    }
}

// MARK: - PIN Entry View (for verification after timer completes)
struct PINEntryView: View {
    @Binding var enteredPIN: String
    let onVerify: (String) -> Bool
    let onSuccess: () -> Void

    @State private var shake = false
    @State private var wrongAttempt = false
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Vibrant purple-blue gradient (matches app idle state)
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.4, blue: 1.0),
                    Color(red: 0.4, green: 0.6, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating decorations
            FloatingDecorationsView(isAnimating: isAnimating)

            VStack(spacing: 30) {
                Spacer()

                // Animated Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .scaleEffect(isAnimating ? 1.15 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 55))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }

                    Text("Time's Up!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Parent: Enter PIN to verify completion")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // PIN dots
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < enteredPIN.count ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(wrongAttempt ? Color.red : Color.white.opacity(0.5), lineWidth: 2)
                            )
                    }
                }
                .offset(x: shake ? -10 : 0)
                .animation(shake ? Animation.linear(duration: 0.05).repeatCount(5, autoreverses: true) : .default, value: shake)

                // Number pad
                VStack(spacing: 16) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 24) {
                            ForEach(1..<4) { col in
                                let number = row * 3 + col
                                PINButton(number: "\(number)") {
                                    addDigit("\(number)")
                                }
                            }
                        }
                    }
                    HStack(spacing: 24) {
                        // Empty space
                        Color.clear.frame(width: 75, height: 75)

                        PINButton(number: "0") {
                            addDigit("0")
                        }

                        // Delete button
                        Button(action: deleteDigit) {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 75, height: 75)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear { isAnimating = true }
    }

    private func addDigit(_ digit: String) {
        guard enteredPIN.count < 4 else { return }

        wrongAttempt = false
        enteredPIN += digit

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if enteredPIN.count == 4 {
            // Verify PIN
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if onVerify(enteredPIN) {
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                    onSuccess()
                } else {
                    // Wrong PIN
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                    wrongAttempt = true
                    shake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shake = false
                        enteredPIN = ""
                    }
                }
            }
        }
    }

    private func deleteDigit() {
        guard !enteredPIN.isEmpty else { return }
        enteredPIN.removeLast()
        wrongAttempt = false

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct PINButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 75, height: 75)
                .background(Circle().fill(Color.white.opacity(0.15)))
        }
    }
}

// MARK: - Quality Rating View (shown after PIN verification)
struct QualityRatingView: View {
    let streakMultiplier: Double
    let onRatingSelected: (TaskRating) -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Vibrant purple-blue gradient (matches app idle state)
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.4, blue: 1.0),
                    Color(red: 0.4, green: 0.6, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating decorations
            FloatingDecorationsView(isAnimating: isAnimating)

            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Text("✅")
                        .font(.system(size: 60))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    Text("How did they do?")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Rate the quality of work")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Rating buttons
                VStack(spacing: 16) {
                    RatingButton(
                        rating: .amazing,
                        multiplier: streakMultiplier,
                        action: onRatingSelected
                    )

                    RatingButton(
                        rating: .good,
                        multiplier: streakMultiplier,
                        action: onRatingSelected
                    )

                    RatingButton(
                        rating: .needsWork,
                        multiplier: streakMultiplier,
                        action: onRatingSelected
                    )
                }
                .padding(.horizontal, 20)

                // Streak multiplier badge
                if streakMultiplier > 1 {
                    HStack(spacing: 6) {
                        Text("🔥")
                        Text("\(streakMultiplier, specifier: "%.1f")x Streak Bonus!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear { isAnimating = true }
    }
}

struct RatingButton: View {
    let rating: TaskRating
    let multiplier: Double
    let action: (TaskRating) -> Void

    @State private var isPressed = false

    private var calculatedStars: Int {
        Int(Double(rating.rawValue) * multiplier)
    }

    private var buttonColor: Color {
        switch rating {
        case .amazing: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case .good: return Color(red: 0.3, green: 0.7, blue: 0.4) // Green
        case .needsWork: return Color(red: 0.5, green: 0.6, blue: 0.7) // Gray-blue
        }
    }

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action(rating)
        }) {
            HStack(spacing: 16) {
                // Icon
                Text(rating.icon)
                    .font(.system(size: 36))

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(rating.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(rating.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Stars earned
                HStack(spacing: 4) {
                    Text("+\(calculatedStars)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(buttonColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(buttonColor.opacity(0.6), lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - PIN Setup Prompt View (shown after first task completion)
struct PINSetupPromptView: View {
    let onSetupNow: () -> Void
    let onMaybeLater: () -> Void
    let onDontAskAgain: () -> Void
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Celebration
                Text("🎉")
                    .font(.system(size: 70))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("Great Job!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                // Explanation
                VStack(spacing: 12) {
                    Text("Want to earn points?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Set up parent verification so a grown-up can confirm you finished your tasks!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 8)

                // Benefits
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Earn points for completed tasks")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Parents can verify your work")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.orange)
                        Text("Track your achievements")
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 30)

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    Button(action: onSetupNow) {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 20))
                            Text("Set Up Now")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                    }

                    Button(action: onMaybeLater) {
                        Text("Maybe Later")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.vertical, 12)
                    }

                    Button(action: onDontAskAgain) {
                        Text("Don't ask again")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - PIN Setup View
struct PINSetupView: View {
    @Binding var isPresented: Bool
    var onSuccess: (() -> Void)? = nil  // Optional callback when PIN is successfully set
    @ObservedObject private var settings = TimerSettings.shared

    @State private var step: SetupStep = .enterPIN
    @State private var firstPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var shake = false
    @State private var errorMessage: String = ""
    @State private var isAnimating = false

    enum SetupStep {
        case enterPIN, confirmPIN
    }

    var currentPIN: Binding<String> {
        step == .enterPIN ? $firstPIN : $confirmPIN
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant purple-blue gradient (matches app idle state)
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.4, blue: 1.0),
                        Color(red: 0.4, green: 0.6, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Floating decorations
                FloatingDecorationsView(isAnimating: isAnimating)

                VStack(spacing: 30) {
                    Spacer()

                    // Animated Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .scaleEffect(isAnimating ? 1.15 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                .animation(
                                    Animation.easeInOut(duration: 1.2)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }

                        Text(step == .enterPIN ? "Create PIN" : "Confirm PIN")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text(step == .enterPIN ? "Enter a 4-digit PIN" : "Enter the PIN again")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }

                    // PIN dots
                    HStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < currentPIN.wrappedValue.count ? Color.orange : Color.white.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                        }
                    }
                    .offset(x: shake ? -10 : 0)
                    .animation(shake ? Animation.linear(duration: 0.05).repeatCount(5, autoreverses: true) : .default, value: shake)

                    // Number pad
                    VStack(spacing: 16) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 24) {
                                ForEach(1..<4) { col in
                                    let number = row * 3 + col
                                    PINButton(number: "\(number)") {
                                        addDigit("\(number)")
                                    }
                                }
                            }
                        }
                        HStack(spacing: 24) {
                            Color.clear.frame(width: 75, height: 75)

                            PINButton(number: "0") {
                                addDigit("0")
                            }

                            Button(action: deleteDigit) {
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 75, height: 75)
                                    .background(Circle().fill(Color.white.opacity(0.15)))
                            }
                        }
                    }

                    // Remove PIN option (if already set)
                    if settings.isVerificationEnabled && step == .enterPIN {
                        Button(action: {
                            settings.parentPIN = nil
                            isPresented = false
                        }) {
                            Text("Remove PIN")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.vertical, 12)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("PIN Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                isAnimating = true
            }
        }
    }

    private func addDigit(_ digit: String) {
        guard currentPIN.wrappedValue.count < 4 else { return }

        errorMessage = ""
        currentPIN.wrappedValue += digit

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if currentPIN.wrappedValue.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                handlePINComplete()
            }
        }
    }

    private func deleteDigit() {
        guard !currentPIN.wrappedValue.isEmpty else { return }
        currentPIN.wrappedValue.removeLast()
        errorMessage = ""

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func handlePINComplete() {
        if step == .enterPIN {
            // Move to confirm step
            step = .confirmPIN
        } else {
            // Verify PINs match
            if firstPIN == confirmPIN {
                // Success!
                settings.parentPIN = firstPIN
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                isPresented = false
                onSuccess?()  // Call the callback if provided
            } else {
                // PINs don't match
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                errorMessage = "PINs don't match. Try again."
                shake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shake = false
                    firstPIN = ""
                    confirmPIN = ""
                    step = .enterPIN
                }
            }
        }
    }
}

// MARK: - Custom Timer Picker View (Fun & Engaging)
struct CustomTimerPickerView: View {
    @Binding var customActivityName: String
    @Binding var customMinutes: Int
    let onStart: (String) -> Void
    let onCancel: () -> Void

    @State private var isAnimating = false
    @State private var floatingOffset: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool

    var isNameEmpty: Bool {
        customActivityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant gradient background
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.4, blue: 0.55),
                        Color(red: 0.9, green: 0.35, blue: 0.7),
                        Color(red: 0.7, green: 0.4, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Floating decorations
                FloatingDecorationsView(isAnimating: isAnimating)

                ScrollView {
                    VStack(spacing: 24) {
                        // Fun header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )

                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                    .animation(
                                        Animation.easeInOut(duration: 1.2)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )
                            }

                            Text("Create Your Timer!")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .padding(.top, 20)

                        // Activity name card
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.yellow)
                                Text("What are you doing?")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            TextField("Type your activity...", text: $customActivityName)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                )
                                .focused($isTextFieldFocused)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 20)

                        // Time picker card
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.cyan)
                                Text("How long?")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            // Visual minute display
                            HStack(spacing: 4) {
                                Text("\(customMinutes)")
                                    .font(.system(size: 60, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("min")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .offset(y: 12)
                            }
                            .scaleEffect(isAnimating ? 1.02 : 0.98)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                            Picker("Minutes", selection: $customMinutes) {
                                ForEach(1..<61) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .clipped()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 20)

                        // Start button
                        Button(action: {
                            let activityName = customActivityName.trimmingCharacters(in: .whitespacesAndNewlines)
                            onStart(activityName)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text("Let's Go!")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                            }
                            .foregroundColor(isNameEmpty ? .white.opacity(0.4) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: isNameEmpty
                                                ? [Color.white.opacity(0.1), Color.white.opacity(0.1)]
                                                : [Color.green, Color.green.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(isNameEmpty ? 0.2 : 0.5), lineWidth: 3)
                            )
                            .shadow(color: isNameEmpty ? .clear : .green.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isNameEmpty)
                        .padding(.horizontal, 20)
                        .scaleEffect(isNameEmpty ? 1.0 : (isAnimating ? 1.02 : 0.98))
                        .animation(
                            isNameEmpty ? nil : Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                        if isNameEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16))
                                Text("Name your activity first!")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .offset(y: floatingOffset * 0.3)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .onAppear {
                isAnimating = true
                floatingOffset = -8
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}

// MARK: - Edit Timer Sheet View (Fun & Engaging)
struct EditTimerSheetView: View {
    let editingActivity: ActivityType?
    @Binding var editingMinutes: Int
    let activityName: String
    let activityIcon: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var isAnimating = false

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.5, blue: 1.0),
                        Color(red: 0.55, green: 0.4, blue: 0.95),
                        Color(red: 0.65, green: 0.35, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Floating decorations
                FloatingDecorationsView(isAnimating: isAnimating)

                VStack(spacing: 28) {
                    // Fun header with activity
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 110, height: 110)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            Image(systemName: activityIcon)
                                .font(.system(size: 50, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .rotationEffect(.degrees(isAnimating ? 5 : -5))
                                .animation(
                                    Animation.easeInOut(duration: 1.2)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }

                        Text("Edit \(activityName)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                    }
                    .padding(.top, 20)

                    // Time picker card
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "timer.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.yellow)
                            Text("Set the time")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        // Visual minute display
                        HStack(spacing: 4) {
                            Text("\(editingMinutes)")
                                .font(.system(size: 70, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("min")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .offset(y: 14)
                        }
                        .scaleEffect(isAnimating ? 1.02 : 0.98)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                        Picker("Minutes", selection: $editingMinutes) {
                            ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 140)
                        .clipped()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.12))
                    )
                    .padding(.horizontal, 20)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: onCancel) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Cancel")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                            )
                        }

                        Button(action: onSave) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Save")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .onAppear {
                isAnimating = true
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Timer")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Floating Decorations View
struct FloatingDecorationsView: View {
    let isAnimating: Bool

    var body: some View {
        GeometryReader { geometry in
            // Floating circles
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.03...0.08)))
                    .frame(width: CGFloat.random(in: 40...100))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .offset(y: isAnimating ? -20 : 20)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 3...5))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }

            // Floating stars
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: CGFloat.random(in: 12...20)))
                    .foregroundColor(.white.opacity(Double.random(in: 0.1...0.2)))
                    .position(
                        x: CGFloat.random(in: 30...(geometry.size.width - 30)),
                        y: CGFloat.random(in: 50...(geometry.size.height - 50))
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: Double.random(in: 8...15))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Settings Sheet View (Fun & Engaging)
struct SettingsSheetView: View {
    @Binding var tickSoundEnabled: Bool
    @Binding var childName: String
    let isVerificationEnabled: Bool
    @Binding var activeTutorialStep: TutorialStep?
    let tutorialPulse: Bool
    let onPINSetupTap: () -> Void
    let onSkipTutorial: () -> Void
    let onDone: () -> Void

    @State private var isAnimating = false
    @State private var editingName: String = ""
    @State private var isEditingName = false

    private var isShowingPINTutorial: Bool {
        activeTutorialStep == .pinSetupRow
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant purple-blue gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.35, blue: 0.85),
                        Color(red: 0.4, green: 0.45, blue: 0.9),
                        Color(red: 0.35, green: 0.4, blue: 0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Floating decorations
                FloatingDecorationsView(isAnimating: isAnimating)

                ScrollView {
                    VStack(spacing: 24) {
                        // Animated header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )

                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 45, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .rotationEffect(.degrees(isAnimating ? 15 : -15))
                                    .animation(
                                        Animation.easeInOut(duration: 2.0)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )
                            }

                            Text("Settings")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)

                        // Profile Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.pink)
                                Text("Profile")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            if isEditingName {
                                HStack(spacing: 12) {
                                    TextField("Name", text: $editingName)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.15))
                                        )

                                    Button(action: {
                                        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !trimmed.isEmpty {
                                            childName = trimmed
                                        }
                                        isEditingName = false
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.green)
                                    }

                                    Button(action: {
                                        isEditingName = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                }
                            } else {
                                Button(action: {
                                    editingName = childName
                                    isEditingName = true
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pink.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                            Text(String(childName.prefix(1)).uppercased())
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.pink)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(childName)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.85)
                                            Text("Tap to change name")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Sound Settings Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan)
                                Text("Sound Settings")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }

                            Toggle(isOn: $tickSoundEnabled) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "metronome.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.green)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Tick Sound")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("Soft tick every second")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                }
                            }
                            .tint(.green)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Parent Controls Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                Text("Parent Controls")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }

                            Button(action: onPINSetupTap) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isVerificationEnabled ? "Change PIN" : "Set Up PIN")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(isVerificationEnabled ? "Verification is active" : "Verify task completion")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    Spacer()
                                    if isVerificationEnabled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.green)
                                    }
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .background(
                            // Tutorial highlight
                            Group {
                                if isShowingPINTutorial {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.orange, lineWidth: 4)
                                        .shadow(color: .orange, radius: 12)
                                        .scaleEffect(tutorialPulse ? 1.05 : 1.0)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .zIndex(isShowingPINTutorial ? 100 : 0)
                        .overlay(alignment: .top) {
                            if isShowingPINTutorial {
                                VStack(spacing: 4) {
                                    TutorialHandPointer(direction: .down)
                                    TutorialTooltip(text: "Parent PIN", caretPosition: .top)
                                }
                                .offset(y: -70)
                            }
                        }


                        Spacer(minLength: 40)
                    }
                    .padding(.top, 10)
                }

                // Skip button for PIN tutorial - subtle, at bottom
                if isShowingPINTutorial {
                    VStack {
                        Spacer()
                        Button(action: onSkipTutorial) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .onAppear { isAnimating = true }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - History Sheet View (Fun & Engaging)
struct HistorySheetView: View {
    let todayCount: Int
    let streak: Int
    let totalCount: Int
    let sessions: [TimerSession]
    let onDone: () -> Void

    @State private var isAnimating = false

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant blue-teal gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.55, blue: 0.8),
                        Color(red: 0.35, green: 0.5, blue: 0.85),
                        Color(red: 0.3, green: 0.45, blue: 0.75)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Floating decorations
                FloatingDecorationsView(isAnimating: isAnimating)

                ScrollView {
                    VStack(spacing: 24) {
                        // Animated header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )

                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 45, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                                    .animation(
                                        Animation.easeInOut(duration: 1.2)
                                            .repeatForever(autoreverses: true),
                                        value: isAnimating
                                    )
                            }

                            Text("Your Progress")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)

                        // Stats cards
                        HStack(spacing: 12) {
                            EnhancedStatCard(
                                title: "Today",
                                value: "\(todayCount)",
                                icon: "calendar",
                                color: .blue,
                                isAnimating: isAnimating
                            )
                            EnhancedStatCard(
                                title: "Streak",
                                value: "\(streak)",
                                icon: "flame.fill",
                                color: .orange,
                                isAnimating: isAnimating
                            )
                            EnhancedStatCard(
                                title: "Total",
                                value: "\(totalCount)",
                                icon: "checkmark.circle.fill",
                                color: .green,
                                isAnimating: isAnimating
                            )
                        }
                        .padding(.horizontal, 20)

                        // Recent sessions
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan)
                                Text("Recent Sessions")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)

                            if sessions.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "clock.badge.questionmark")
                                        .font(.system(size: 60))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white.opacity(0.5), .white.opacity(0.3)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                                        .animation(
                                            Animation.easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true),
                                            value: isAnimating
                                        )
                                    Text("No sessions yet!")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Complete a timer to see your history")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(sessions) { session in
                                        EnhancedSessionRow(session: session)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 10)
                }
            }
            .onAppear { isAnimating = true }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Stat Card
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Enhanced Session Row
struct EnhancedSessionRow: View {
    let session: TimerSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: session.activityIcon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.activity)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(session.completedAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                // Show actual time spent (round up to at least 1 min)
                let minutes = max(1, (session.actualTime + 59) / 60)
                Text("\(minutes) min")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = TimerSettings.shared
    @State private var childName: String = ""
    @State private var isAnimating = false
    @FocusState private var isTextFieldFocused: Bool

    var isNameEmpty: Bool {
        childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            // Vibrant gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.5, green: 0.35, blue: 1.0),
                    Color(red: 0.65, green: 0.35, blue: 0.95),
                    Color(red: 0.55, green: 0.4, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating decorations
            FloatingDecorationsView(isAnimating: isAnimating)

            VStack(spacing: 30) {
                Spacer()

                // Welcome header
                VStack(spacing: 16) {
                    ZStack {
                        // Glow circles
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: CGFloat(140 + index * 25), height: CGFloat(140 + index * 25))
                                .scaleEffect(isAnimating ? 1.1 : 0.95)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }

                        Image(systemName: "timer.circle.fill")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 20, x: 0, y: 10)
                            .scaleEffect(isAnimating ? 1.1 : 0.95)
                            .rotationEffect(.degrees(isAnimating ? 5 : -5))
                            .animation(
                                Animation.easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }

                    Text("Welcome!")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                    Text("Let's set up your timer")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Name input card
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("What's your name?")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    TextField("Type your name...", text: $childName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                        )
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 24)

                // Let's Go button
                Button(action: {
                    let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
                    settings.childName = name
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        Text("Let's Go!")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                    }
                    .foregroundColor(isNameEmpty ? .white.opacity(0.4) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: isNameEmpty
                                        ? [Color.white.opacity(0.1), Color.white.opacity(0.1)]
                                        : [Color.green, Color.green.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(isNameEmpty ? 0.2 : 0.5), lineWidth: 3)
                    )
                    .shadow(color: isNameEmpty ? .clear : .green.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .disabled(isNameEmpty)
                .padding(.horizontal, 24)
                .scaleEffect(isNameEmpty ? 1.0 : (isAnimating ? 1.02 : 0.98))
                .animation(
                    isNameEmpty ? nil : Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

                if isNameEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                        Text("Enter your name to continue")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView()
}
