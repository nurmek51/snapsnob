import SwiftUI

// MARK: - Spotlight Shape
/// A shape that creates a dimmed overlay with a transparent cutout
struct SpotlightShape: Shape {
    let spotlightFrame: CGRect
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Add the full screen rect
        path.addRect(rect)
        
        // Add the spotlight area (as a hole)
        if cornerRadius > 0 {
            path.addRoundedRect(in: spotlightFrame, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        } else {
            path.addRect(spotlightFrame)
        }
        
        return path
    }
}

// MARK: - Spotlight Overlay View
/// Creates a spotlight effect by dimming everything except the target area
struct SpotlightOverlay: View {
    let targetFrame: CGRect
    let cornerRadius: CGFloat
    let dimOpacity: Double
    
    init(targetFrame: CGRect, cornerRadius: CGFloat = 0, dimOpacity: Double = 0.75) {
        self.targetFrame = targetFrame
        self.cornerRadius = cornerRadius
        self.dimOpacity = dimOpacity
    }
    
    var body: some View {
        SpotlightShape(spotlightFrame: targetFrame, cornerRadius: cornerRadius)
            .fill(Color.black.opacity(dimOpacity), style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - Placeholder Photo Card
/// A minimalist placeholder card representing a photo during onboarding
struct PlaceholderPhotoCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                .fill(AppColors.cardBackground(for: themeManager.isDarkMode))
                .overlay(
                    RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius)
                        .stroke(AppColors.border(for: themeManager.isDarkMode), lineWidth: 1)
                )
            
            // Photo icon
            Image(systemName: "photo")
                .font(.system(size: min(size.width, size.height) * 0.3))
                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode).opacity(0.3))
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Animated Gesture Indicator
/// Shows an animated hand or arrow for gesture hints
struct GestureIndicator: View {
    enum GestureType {
        case swipeRight, swipeLeft, doubleTap
    }
    
    let type: GestureType
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Group {
            switch type {
            case .swipeRight:
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-30))
                    .offset(x: offset)
                    .opacity(opacity)
                    .onAppear {
                        animateSwipeRight()
                    }
                
            case .swipeLeft:
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(30))
                    .offset(x: -offset)
                    .opacity(opacity)
                    .onAppear {
                        animateSwipeLeft()
                    }
                
            case .doubleTap:
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .onAppear {
                    animateDoubleTap()
                }
            }
        }
    }
    
    private func animateSwipeRight() {
        offset = -30
        opacity = 0.3
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            offset = 100
            opacity = 1
        }
        
        // Reset animation
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            offset = -30
            opacity = 0.3
        }
    }
    
    private func animateSwipeLeft() {
        offset = -30
        opacity = 0.3
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            offset = 100
            opacity = 1
        }
        
        // Reset animation
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            offset = -30
            opacity = 0.3
        }
    }
    
    private func animateDoubleTap() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: false)) {
            scale = 1.3
            opacity = 0.3
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            scale = 1
            opacity = 1
        }
    }
} 