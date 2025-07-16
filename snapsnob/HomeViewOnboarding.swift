import SwiftUI

struct HomeViewOnboarding: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var didSwipeRight: Bool
    @Binding var didSwipeLeft: Bool
    @Binding var didDoubleTap: Bool
    
    // Card position for spotlight
    @State private var cardFrame: CGRect = .zero
    
    var body: some View {
        if onboardingManager.isOnboardingActive {
            GeometryReader { geometry in
                ZStack {
                    // Calculate card frame
                    let cardSize = DeviceInfo.shared.cardSize()
                    let cardX = (geometry.size.width - cardSize.width) / 2
                    let cardY = (geometry.size.height - cardSize.height) / 2
                    let calculatedFrame = CGRect(x: cardX, y: cardY, width: cardSize.width, height: cardSize.height)
                    
                    // Only show overlay for gesture steps
                    switch onboardingManager.currentStep {
                    case .rightSwipe, .leftSwipe, .doubleTap:
                        // Spotlight overlay
                        SpotlightOverlay(
                            targetFrame: calculatedFrame,
                            cornerRadius: DeviceInfo.shared.screenSize.cornerRadius,
                            dimOpacity: 0.85
                        )
                        
                        // Placeholder card in spotlight
                        PlaceholderPhotoCard(size: cardSize)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .allowsHitTesting(false)
                        
                        // Gesture overlay
                        gestureInstructionOverlay(geometry: geometry, cardFrame: calculatedFrame)
                        
                    default:
                        EmptyView()
                    }
                }
            }
            .ignoresSafeArea()
            .onChange(of: didSwipeRight) { newValue in
                if newValue && onboardingManager.currentStep == .rightSwipe {
                    onboardingManager.nextStep()
                    didSwipeRight = false
                }
            }
            .onChange(of: didSwipeLeft) { newValue in
                if newValue && onboardingManager.currentStep == .leftSwipe {
                    onboardingManager.nextStep()
                    didSwipeLeft = false
                }
            }
            .onChange(of: didDoubleTap) { newValue in
                if newValue && onboardingManager.currentStep == .doubleTap {
                    onboardingManager.nextStep()
                    didDoubleTap = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func gestureInstructionOverlay(geometry: GeometryProxy, cardFrame: CGRect) -> some View {
        VStack {
            // Top instruction area
            VStack(spacing: 12) {
                // Instruction text in a minimal card
                VStack(spacing: 8) {
                    Text(onboardingManager.currentStep.description)
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.body))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.9))
                )
                .padding(.horizontal, 32)
                
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        onboardingManager.skipOnboarding()
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
                }
                .padding(.horizontal, 32)
            }
            .padding(.top, DeviceInfo.SafeAreaHelper.topInset + 20)
            
            Spacer()
            
            // Gesture indicators positioned relative to card
            gestureIndicatorOverlay(geometry: geometry, cardFrame: cardFrame)
                .padding(.bottom, 100)
        }
    }
    
    @ViewBuilder
    private func gestureIndicatorOverlay(geometry: GeometryProxy, cardFrame: CGRect) -> some View {
        switch onboardingManager.currentStep {
        case .rightSwipe:
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    GestureIndicator(type: .swipeRight)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("onboarding.swipeRight.hint".localized)
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .offset(x: -40)
            }
            .frame(maxWidth: geometry.size.width)
            .position(x: geometry.size.width / 2, y: cardFrame.midY)
            
        case .leftSwipe:
            HStack {
                VStack(spacing: 12) {
                    GestureIndicator(type: .swipeLeft)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("onboarding.swipeLeft.hint".localized)
                            .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .offset(x: 40)
                Spacer()
            }
            .frame(maxWidth: geometry.size.width)
            .position(x: geometry.size.width / 2, y: cardFrame.midY)
            
        case .doubleTap:
            VStack(spacing: 12) {
                GestureIndicator(type: .doubleTap)
                
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 16, weight: .semibold))
                    Text("onboarding.doubleTap.hint".localized)
                        .font(.system(size: DeviceInfo.shared.screenSize.fontSize.caption))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }
            .position(x: geometry.size.width / 2, y: cardFrame.midY)
            
        default:
            EmptyView()
        }
    }
} 