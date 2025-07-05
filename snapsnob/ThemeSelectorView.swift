import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Выберите тему")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("Тема будет применена ко всему приложению")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
                
                VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 12) {
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
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 0 : 20)
                
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
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .body)
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
            HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16) {
                // Theme icon
                Image(systemName: theme.icon)
                    .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                    .foregroundColor(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : AppColors.secondaryText(for: themeManager.isDarkMode))
                    .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 30)
                
                VStack(alignment: .leading, spacing: UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4) {
                    Text(theme.displayName)
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .headline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text(themeDescription(for: theme))
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .body : .caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                } else {
                    Image(systemName: "circle")
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .largeTitle : .title2)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20)
            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16)
            .background(
                RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
                    .fill(isSelected ? AppColors.cardBackground(for: themeManager.isDarkMode) : AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    .overlay(
                        RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 12)
                            .stroke(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : Color.clear, lineWidth: UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2)
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