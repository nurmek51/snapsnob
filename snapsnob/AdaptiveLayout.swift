import SwiftUI

// MARK: - Device Size Detection
/// Comprehensive device size detection for adaptive layouts
struct DeviceInfo {
    static let shared = DeviceInfo()
    
    /// Device screen size categories
    enum ScreenSize {
        case compact      // iPhone SE, iPhone 12 mini
        case standard     // iPhone 14, iPhone 15
        case plus         // iPhone 14 Plus, iPhone 15 Plus, iPhone 16 Plus
        case max          // iPhone 14 Pro Max, iPhone 15 Pro Max, iPhone 16 Pro Max
        case iPad
        case iPadPro
        
        var horizontalPadding: CGFloat {
            switch self {
            case .compact:
                return 16
            case .standard:
                return 20
            case .plus, .max:
                // Align Plus/Max phones with Standard phones for consistent layout across iPhone models
                return 20
            case .iPad:
                return 30
            case .iPadPro:
                return 40
            }
        }
        
        var gridColumns: Int {
            switch self {
            case .compact:
                return 2
            case .standard:
                return 3
            // Use the same column count as Standard phones to avoid layout discrepancies
            case .plus, .max:
                return 3
            case .iPad:
                return 5
            case .iPadPro:
                return 6
            }
        }
        
        var gridSpacing: CGFloat {
            switch self {
            case .compact:
                return 8
            case .standard:
                return 12
            // Match Standard phone spacing for Plus/Max devices
            case .plus, .max:
                return 12
            case .iPad:
                return 20
            case .iPadPro:
                return 24
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .compact:
                return 12
            case .standard:
                return 16
            // Keep the same corner radius as Standard phones
            case .plus, .max:
                return 16
            case .iPad:
                return 24
            case .iPadPro:
                return 28
            }
        }
        
        var fontSize: (title: CGFloat, body: CGFloat, caption: CGFloat) {
            switch self {
            case .compact:
                return (20, 14, 12)
            case .standard:
                return (22, 16, 14)
            // Use Standard phone font sizes for Plus/Max
            case .plus, .max:
                return (22, 16, 14)
            case .iPad:
                return (28, 20, 18)
            case .iPadPro:
                return (32, 22, 20)
            }
        }
    }
    
    /// Current device screen size category
    var screenSize: ScreenSize {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad detection
            if max(screenWidth, screenHeight) > 1194 { // iPad Pro 12.9"
                return .iPadPro
            } else {
                return .iPad
            }
        } else {
            // iPhone detection based on screen width
            if screenWidth <= 375 { // iPhone SE, iPhone 12 mini
                return .compact
            } else if screenWidth <= 390 { // iPhone 14, iPhone 15
                return .standard
            } else if screenWidth <= 414 { // iPhone 14 Plus, iPhone 15 Plus, iPhone 16 Plus
                return .plus
            } else { // iPhone Pro Max models
                return .max
            }
        }
    }
    
    /// Check if device is iPhone
    var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    /// Check if device is iPad
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - Adaptive Layout Modifiers
/// Adaptive padding modifier that adjusts to device size
struct AdaptivePaddingModifier: ViewModifier {
    let multiplier: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DeviceInfo.shared.screenSize.horizontalPadding * multiplier)
    }
}

/// Adaptive font size modifier
struct AdaptiveFontModifier: ViewModifier {
    let style: FontStyle
    
    enum FontStyle {
        case title, body, caption
    }
    
    func body(content: Content) -> some View {
        let sizes = DeviceInfo.shared.screenSize.fontSize
        let fontSize: CGFloat
        
        switch style {
        case .title:
            fontSize = sizes.title
        case .body:
            fontSize = sizes.body
        case .caption:
            fontSize = sizes.caption
        }
        
        return content
            .font(.system(size: fontSize))
    }
}

/// Adaptive corner radius modifier
struct AdaptiveCornerRadiusModifier: ViewModifier {
    let multiplier: CGFloat
    
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: DeviceInfo.shared.screenSize.cornerRadius * multiplier))
    }
}

/// Adaptive grid columns modifier
struct AdaptiveGridModifier: ViewModifier {
    let baseColumns: Int
    
    func body(content: Content) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), 
                           count: min(baseColumns, DeviceInfo.shared.screenSize.gridColumns))
        return content
    }
}

/// Comprehensive adaptive layout modifier
struct AdaptiveLayoutModifier: ViewModifier {
    let usePadding: Bool
    let useCornerRadius: Bool
    
    func body(content: Content) -> some View {
        let deviceInfo = DeviceInfo.shared
        
        return content
            .modifier(AdaptivePaddingModifier(multiplier: usePadding ? 1.0 : 0.0))
            .modifier(AdaptiveCornerRadiusModifier(multiplier: useCornerRadius ? 1.0 : 0.0))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - View Extensions
extension View {
    /// Applies adaptive padding based on device size
    func adaptivePadding(_ multiplier: CGFloat = 1.0) -> some View {
        self.modifier(AdaptivePaddingModifier(multiplier: multiplier))
    }
    
    /// Applies adaptive font size based on device size
    func adaptiveFont(_ style: AdaptiveFontModifier.FontStyle) -> some View {
        self.modifier(AdaptiveFontModifier(style: style))
    }
    
    /// Applies adaptive corner radius based on device size
    func adaptiveCornerRadius(_ multiplier: CGFloat = 1.0) -> some View {
        self.modifier(AdaptiveCornerRadiusModifier(multiplier: multiplier))
    }
    
    /// Applies comprehensive adaptive layout
    func adaptiveLayout(usePadding: Bool = true, useCornerRadius: Bool = true) -> some View {
        self.modifier(AdaptiveLayoutModifier(usePadding: usePadding, useCornerRadius: useCornerRadius))
    }
    
    /// Creates adaptive grid columns
    func adaptiveGrid(baseColumns: Int = 3) -> [GridItem] {
        let columns = min(baseColumns, DeviceInfo.shared.screenSize.gridColumns)
        return Array(repeating: GridItem(.flexible(), spacing: DeviceInfo.shared.screenSize.gridSpacing), 
                    count: columns)
    }
    
    /// Legacy compatibility - optimizes the view's layout for the current device
    func constrainedToDevice(usePadding: Bool = true) -> some View {
        self.adaptiveLayout(usePadding: usePadding, useCornerRadius: false)
    }
}

// MARK: - Helper Functions
extension DeviceInfo {
    /// Get adaptive spacing for the current device
    func spacing(_ multiplier: CGFloat = 1.0) -> CGFloat {
        screenSize.gridSpacing * multiplier
    }
    
    /// Get adaptive card size for the current device
    func cardSize() -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let padding = screenSize.horizontalPadding * 2
        let availableWidth = screenWidth - padding
        
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        
        switch screenSize {
        case .compact:
            // iPhone SE/mini - compact but usable
            cardWidth = availableWidth * 0.95
            cardHeight = cardWidth * 1.4 // 1.4:1 aspect ratio
        case .standard:
            // Use the same proportions as the Plus model for visual consistency
            cardWidth = availableWidth * 0.9
            cardHeight = cardWidth * 1.3 // 1.3:1 aspect ratio (matches .plus)
        case .plus:
            // iPhone Plus family – baseline for phone layout
            cardWidth = availableWidth * 0.9
            cardHeight = cardWidth * 1.3
        case .max:
            // Unify Pro Max with Plus proportions as well
            cardWidth = availableWidth * 0.9
            cardHeight = cardWidth * 1.3
        case .iPad:
            // iPad - more compact relative to screen
            cardWidth = min(availableWidth * 0.7, 500)
            cardHeight = cardWidth * 1.25 // 1.25:1 aspect ratio
        case .iPadPro:
            // iPad Pro - take advantage of large screen
            cardWidth = min(availableWidth * 0.6, 600)
            cardHeight = cardWidth * 1.2 // 1.2:1 aspect ratio
        }
        
        return CGSize(width: cardWidth, height: cardHeight)
    }
} 