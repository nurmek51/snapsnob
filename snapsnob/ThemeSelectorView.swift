import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingLanguageSelector = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            AppColors.background(for: themeManager.isDarkMode)
                .ignoresSafeArea()
            
            VStack(spacing: DeviceInfo.shared.spacing(1.5)) {
                // Top bar with custom exit button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .adaptiveFont(.title)
                            .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                            .padding(DeviceInfo.shared.spacing(0.5))
                    }
                    .padding(.leading, DeviceInfo.shared.screenSize.horizontalPadding)
                    Spacer()
                    Button("action.done".localized) {
                        dismiss()
                    }
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .padding(.trailing, DeviceInfo.shared.screenSize.horizontalPadding)
                }
                .safeAreaHeader()
                
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    Text("theme.choose".localized)
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("theme.description".localized)
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding * 1.2)
                
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeOptionCard(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                themeManager.setTheme(theme)
                            }
                        }
                    }
                    
                    // Language selector button
                    Button {
                        showingLanguageSelector = true
                    } label: {
                        HStack(spacing: DeviceInfo.shared.spacing()) {
                            Image(systemName: "globe")
                                .adaptiveFont(.title)
                                .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                                .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 2)
                            
                            VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.3)) {
                                Text("settings.language".localized)
                                    .adaptiveFont(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                                
                                Text("language.current".localized(with: localizationManager.currentLanguage.displayName))
                                    .adaptiveFont(.caption)
                                    .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .adaptiveFont(.title)
                                .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        }
                        .adaptivePadding()
                        .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.8)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                                .fill(AppColors.secondaryBackground(for: themeManager.isDarkMode))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, DeviceInfo.shared.spacing())
                }
                .adaptivePadding()
                
                Spacer()
            }
            .constrainedToDevice()
        }
        .id(themeManager.currentTheme) // Force redraw on theme change
        .sheet(isPresented: $showingLanguageSelector) {
            LanguageSelectorView()
        }
    }
}

struct ThemeOptionCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DeviceInfo.shared.spacing()) {
                // Theme icon
                Image(systemName: theme.icon)
                    .adaptiveFont(.title)
                    .foregroundColor(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : AppColors.secondaryText(for: themeManager.isDarkMode))
                    .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 2)
                
                VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.3)) {
                    Text(theme.displayName)
                        .adaptiveFont(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text(themeDescription(for: theme))
                        .adaptiveFont(.caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .adaptiveFont(.title)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                } else {
                    Image(systemName: "circle")
                        .adaptiveFont(.title)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
            }
            .adaptivePadding()
            .padding(.vertical, DeviceInfo.shared.screenSize.horizontalPadding * 0.8)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                    .fill(isSelected ? AppColors.cardBackground(for: themeManager.isDarkMode) : AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                            .stroke(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : Color.clear, lineWidth: DeviceInfo.shared.screenSize == .compact ? 2 : 3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func themeDescription(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "theme.systemDescription".localized
        case .light:
            return "theme.lightDescription".localized
        case .dark:
            return "theme.darkDescription".localized
        }
    }
}

#Preview {
    ThemeSelectorView()
        .environmentObject(ThemeManager())
} 