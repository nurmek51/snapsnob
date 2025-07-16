import SwiftUI

struct OnboardingView: View {
    var onFinish: (() -> Void)? = nil
    @StateObject private var onboardingManager = OnboardingManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    // Animation states
    @State private var showingContent = false
    @State private var pulseScale: CGFloat = 1
    @State private var swipeOffset: CGFloat = 0
    @State private var tapScale: CGFloat = 1
    
    var body: some View {
        if onboardingManager.isOnboardingActive {
            ZStack {
                // Full screen dim
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture { } // Prevent tap through
                
                // Content based on current step
                Group {
                    switch onboardingManager.currentStep {
                    case .rightSwipe:
                        rightSwipeOverlay
                    case .leftSwipe:
                        leftSwipeOverlay
                    case .doubleTap:
                        doubleTapOverlay
                    case .storySeries:
                        storySeriesOverlay
                    case .trashBin:
                        trashBinOverlay
                    case .privacyNotice:
                        privacyNoticeOverlay
                    default:
                        defaultOnboardingOverlay
                    }
                }
                .opacity(showingContent ? 1 : 0)
                .scaleEffect(showingContent ? 1 : 0.95)
                // Кнопка skipButton полностью удалена
            }
            .transition(.opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingContent = true
                }
                startPulseAnimation()
                startSwipeAnimation()
                startTapAnimation()
            }
        }
    }
    
    // MARK: - Skip Button
    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // Skip to privacy notice instead of completing onboarding
                    onboardingManager.skipToPrivacyNotice()
                }) {
                    Text("onboarding.skip".localized)
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                }
                .padding()
            }
            .padding(.top, DeviceInfo.SafeAreaHelper.topInset)
            Spacer()
        }
    }
    
    // MARK: - Story Series Overlay
    private var storySeriesOverlay: some View {
        GeometryReader { geometry in
            let padding = DeviceInfo.shared.screenSize.horizontalPadding
            let storyCircleSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
            let spacing: CGFloat = DeviceInfo.shared.screenSize.gridSpacing
            let trashIconWidth: CGFloat = DeviceInfo.shared.screenSize.horizontalPadding * 3.5 + 20
            let availableWidth = geometry.size.width - trashIconWidth - padding * 2
            let maxCircles = max(2, Int((availableWidth + spacing) / (storyCircleSize + spacing)))
            let circles = min(maxCircles, UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4)
            let titleHeight: CGFloat = DeviceInfo.shared.screenSize.fontSize.title + DeviceInfo.shared.spacing(0.5)
            let topPadding = DeviceInfo.SafeAreaHelper.headerTopPadding
            let spotlightY = topPadding + titleHeight + DeviceInfo.shared.spacing(0.5)
            let spotlightFrame = CGRect(x: padding, y: spotlightY, width: availableWidth, height: storyCircleSize + 20)
            
            ZStack {
                // Spotlight on story area
                SpotlightOverlay(
                    targetFrame: spotlightFrame,
                    cornerRadius: 16,
                    dimOpacity: 0
                )
                
                // Placeholder story series
                HStack(spacing: spacing) {
                    ForEach(0..<circles, id: \.self) { index in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.3))
                                )
                                .frame(width: storyCircleSize, height: storyCircleSize)
                            Text("Series \(index + 1)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.leading, padding)
                .frame(width: availableWidth, alignment: .leading)
                .position(x: padding + availableWidth / 2, y: spotlightY + storyCircleSize / 2 + 10)
                
                // Instruction content
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        instructionCard(onboardingManager.currentStep.description)
                        continueButton {
                            onboardingManager.nextStep()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - Trash Bin Overlay
    private var trashBinOverlay: some View {
        GeometryReader { geometry in
            let padding = DeviceInfo.shared.screenSize.horizontalPadding
            let storyCircleSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 95 : 75
            let spacing: CGFloat = DeviceInfo.shared.screenSize.gridSpacing
            let availableWidth = geometry.size.width - padding * 2
            let maxCircles = max(1, Int((availableWidth - storyCircleSize - spacing) / (storyCircleSize + spacing)))
            let circles = min(maxCircles, UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4)
            let titleHeight: CGFloat = DeviceInfo.shared.screenSize.fontSize.title + DeviceInfo.shared.spacing(0.5)
            let topPadding = DeviceInfo.SafeAreaHelper.headerTopPadding
            let rowY = topPadding + titleHeight + DeviceInfo.shared.spacing(0.5) + storyCircleSize / 2 + 10
            // Trash icon is placed right after the last circle
            let trashIndex = circles // index in HStack
            let trashX = padding + CGFloat(trashIndex) * (storyCircleSize + spacing) + storyCircleSize / 2
            let spotlightFrame = CGRect(
                x: trashX - storyCircleSize / 2 - 10,
                y: rowY - storyCircleSize / 2 - 10,
                width: storyCircleSize + 20,
                height: storyCircleSize + 20
            )

            ZStack {
                SpotlightOverlay(
                    targetFrame: spotlightFrame,
                    cornerRadius: spotlightFrame.width / 2,
                    dimOpacity: 0
                )

                // Story circles row + trash icon
                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<circles, id: \ .self) { index in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.3))
                                )
                                .frame(width: storyCircleSize, height: storyCircleSize)
                            Text("Series \(index + 1)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    // Trash icon (same size as circles)
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: storyCircleSize, height: storyCircleSize)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 2)
                                )
                            Image(systemName: "trash.fill")
                                .font(.system(size: storyCircleSize * 0.57))
                                .foregroundColor(.white)
                        }
                        Text("")
                            .font(.system(size: 10))
                    }
                }
                .padding(.leading, padding)
                .position(x: padding + (storyCircleSize + spacing) * CGFloat(circles) / 2 + storyCircleSize / 2 + spacing / 2, y: rowY)

                // Instruction content
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        instructionCard(onboardingManager.currentStep.description)
                        continueButton {
                            onboardingManager.nextStep()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - Privacy Notice Overlay
    private var privacyNoticeOverlay: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Privacy icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Privacy text card
            VStack(spacing: 24) {
                instructionCard(onboardingManager.currentStep.description)
                
                continueButton {
                    // Complete onboarding - permission will be requested when needed
                    onboardingManager.skipOnboarding()
                    onFinish?()
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Right Swipe Overlay
    private var rightSwipeOverlay: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                // Interactive card
                InteractiveOnboardingCard(
                    dragOffset: $swipeOffset,
                    onSwipeCompleted: { direction in
                        if direction == .right {
                            onboardingManager.nextStep()
                        }
                    }
                )
                
                // Swipe indicator
                Image(systemName: "arrow.right")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: swipeOffset + 60)
                    .opacity(0.7)
            }
            
            // Action buttons positioned below card
            HStack(spacing: DeviceInfo.shared.screenSize.horizontalPadding * 1.5) {
                // Trash button (disabled)
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
                
                // Favorite button (disabled)
                Button(action: {}) {
                    Image(systemName: "heart")
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
                
                // Keep button (active)
                Button(action: {
                    onboardingManager.nextStep()
                }) {
                    Image(systemName: "checkmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                // Активная кнопка — не отключаем и не затемняем
            }
            .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding)
            
            instructionCard(onboardingManager.currentStep.description)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Left Swipe Overlay
    private var leftSwipeOverlay: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                // Interactive card
                InteractiveOnboardingCard(
                    dragOffset: $swipeOffset,
                    onSwipeCompleted: { direction in
                        if direction == .left {
                            onboardingManager.nextStep()
                        }
                    }
                )
                
                // Swipe indicator
                Image(systemName: "arrow.left")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: swipeOffset - 60)
                    .opacity(0.7)
            }
            
            // Action buttons positioned below card
            HStack(spacing: DeviceInfo.shared.screenSize.horizontalPadding * 1.5) {
                // Trash button (active)
                Button(action: {
                    onboardingManager.nextStep()
                }) {
                    Image(systemName: "xmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                // Активная кнопка — не отключаем и не затемняем
                
                // Favorite button (disabled)
                Button(action: {}) {
                    Image(systemName: "heart")
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
                
                // Keep button (disabled)
                Button(action: {}) {
                    Image(systemName: "checkmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
            }
            .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding)
            
            instructionCard(onboardingManager.currentStep.description)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Double Tap Overlay
    private var doubleTapOverlay: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                // Interactive card
                InteractiveOnboardingCard(
                    dragOffset: .constant(0),
                    onDoubleTap: {
                        onboardingManager.nextStep()
                    }
                )
                
                // Tap indicator
                Image(systemName: "hand.tap")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(tapScale)
                    .opacity(0.7)
            }
            
            // Action buttons positioned below card
            HStack(spacing: DeviceInfo.shared.screenSize.horizontalPadding * 1.5) {
                // Trash button (disabled)
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
                
                // Favorite button with highlight (active)
                Button(action: {
                    onboardingManager.nextStep()
                }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.title, weight: .semibold))
                        .foregroundColor(.red)
                        .scaleEffect(tapScale)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                // Активная кнопка — не отключаем и не затемняем
                
                // Keep button (disabled)
                Button(action: {}) {
                    Image(systemName: "checkmark")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                }
                .buttonStyle(TransparentCircleButtonStyle(size: DeviceInfo.shared.screenSize.horizontalPadding * 3))
                .disabled(true)
                .opacity(0.5)
            }
            .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding)
            
            instructionCard(onboardingManager.currentStep.description)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Default Overlay for basic steps
    private var defaultOnboardingOverlay: some View {
        VStack {
            Spacer()
            instructionCard(onboardingManager.currentStep.description)
            continueButton {
                onboardingManager.nextStep()
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Helper Views
    private func instructionCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
            )
    }
    
    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(onboardingManager.currentStep == .privacyNotice ? 
                 "onboarding.grantAccess".localized : 
                 "onboarding.continue".localized)
                .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body, weight: .semibold))
                .foregroundColor(AppColors.primaryText(for: !themeManager.isDarkMode))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(AppColors.accent(for: themeManager.isDarkMode))
                )
        }
    }
    
    // MARK: - Animations
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
    private func startSwipeAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            swipeOffset = 60
        }
    }
    private func startTapAnimation() {
        withAnimation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            tapScale = 1.25
        }
    }
} 

// MARK: - Interactive Onboarding Card
struct InteractiveOnboardingCard: View {
    @Binding var dragOffset: CGFloat
    var onSwipeCompleted: ((SwipeDirection) -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentDragOffset: CGSize = .zero
    
    private var cardSize: CGSize {
        DeviceInfo.shared.cardSize()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .frame(width: cardSize.width, height: cardSize.height)
                .shadow(radius: 10)
                .overlay(
                    VStack {
                        Spacer()
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.3))
                        Text("Sample Photo")
                            .font(.title2)
                            .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.5))
                        Spacer()
                    }
                )
        }
        .offset(x: currentDragOffset.width)
        .rotationEffect(.degrees(Double(currentDragOffset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { value in
                    currentDragOffset = value.translation
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let horizontalThreshold: CGFloat = 100
                    
                    if abs(value.translation.width) > horizontalThreshold {
                        if value.translation.width < 0 {
                            onSwipeCompleted?(.left)
                        } else {
                            onSwipeCompleted?(.right)
                        }
                    }
                    
                    withAnimation(.spring()) {
                        currentDragOffset = .zero
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
    }
} 
