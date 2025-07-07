import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DeviceInfo.shared.spacing(1.5)) {
                VStack(spacing: DeviceInfo.shared.spacing()) {
                    Text("Выберите тему")
                        .adaptiveFont(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("Тема будет применена ко всему приложению")
                        .adaptiveFont(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DeviceInfo.shared.screenSize.horizontalPadding * 2)
                
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
                }
                .adaptivePadding()
                
                Spacer()
            }
            .constrainedToDevice()
            .background(AppColors.background(for: themeManager.isDarkMode).ignoresSafeArea(.all, edges: .horizontal))
            .navigationTitle("Настройки темы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .adaptiveFont(.body)
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                }
            }
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
            return "Следует системным настройкам"
        case .light:
            return "Всегда светлая тема"
        case .dark:
            return "Всегда темная тема"
        }
    }
}

#Preview {
    ThemeSelectorView()
        .environmentObject(ThemeManager())
} 