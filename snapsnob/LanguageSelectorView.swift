import SwiftUI

struct LanguageSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeveloperAlert = false
    
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
                    Text("language.title".localized)
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("language.current".localized(with: localizationManager.currentLanguage.displayName))
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding * 1.2)
                
                // Developer override indicator
                if localizationManager.isDeveloperOverride {
                    VStack(spacing: DeviceInfo.shared.spacing(0.3)) {
                        Text("language.developerOverride".localized)
                            .adaptiveFont(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Button("language.clearOverride".localized) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                localizationManager.clearDeveloperOverride()
                            }
                        }
                        .adaptiveFont(.caption)
                        .foregroundColor(.orange)
                        .underline()
                    }
                    .adaptivePadding()
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.standardCornerRadius)
                            .fill(.orange.opacity(0.1))
                    )
                    .adaptivePadding(1.2)
                }
                
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        LanguageOptionCard(
                            language: language,
                            isSelected: localizationManager.currentLanguage == language,
                            isDeveloperOverride: localizationManager.isDeveloperOverride && localizationManager.currentLanguage == language
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                localizationManager.setLanguage(language)
                            }
                        } onLongPress: {
                            // Long press for developer override
                            showingDeveloperAlert = true
                        }
                    }
                    
                    // System language reset button
                    Button("language.resetToSystem".localized) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            localizationManager.resetToSystemLanguage()
                        }
                    }
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .padding(.top, DeviceInfo.shared.spacing())
                }
                .adaptivePadding()
                
                Spacer()
            }
            .constrainedToDevice()
        }
        .alert("Developer Override", isPresented: $showingDeveloperAlert) {
            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                Button(language.displayName) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        localizationManager.setDeveloperOverride(language)
                    }
                }
            }
            Button("action.cancel".localized, role: .cancel) { }
        } message: {
            Text("Select language for developer testing. This will override system language detection.")
        }
        .id(localizationManager.currentLanguage) // Force redraw on language change
    }
}

struct LanguageOptionCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let language: SupportedLanguage
    let isSelected: Bool
    let isDeveloperOverride: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DeviceInfo.shared.spacing()) {
                // Language icon
                Image(systemName: languageIcon(for: language))
                    .adaptiveFont(.title)
                    .foregroundColor(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : AppColors.secondaryText(for: themeManager.isDarkMode))
                    .frame(width: DeviceInfo.shared.screenSize.horizontalPadding * 2)
                
                VStack(alignment: .leading, spacing: DeviceInfo.shared.spacing(0.3)) {
                    HStack {
                        Text(language.nativeName)
                            .adaptiveFont(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                        
                        if isDeveloperOverride {
                            Text("DEV")
                                .adaptiveFont(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.orange.opacity(0.2))
                                )
                        }
                    }
                    
                    Text(language.displayName)
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
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    private func languageIcon(for language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return "textformat.abc"
        case .russian:
            return "textformat"
        }
    }
}

#Preview {
    LanguageSelectorView()
        .environmentObject(ThemeManager())
        .environmentObject(LocalizationManager.shared)
} 