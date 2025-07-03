import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Выберите тему")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text("Тема будет применена ко всему приложению")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
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
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(AppColors.background(for: themeManager.isDarkMode))
            .navigationTitle("Настройки темы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
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
            HStack(spacing: 16) {
                // Theme icon
                Image(systemName: theme.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : AppColors.secondaryText(for: themeManager.isDarkMode))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
                    
                    Text(themeDescription(for: theme))
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(AppColors.secondaryText(for: themeManager.isDarkMode))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.cardBackground(for: themeManager.isDarkMode) : AppColors.secondaryBackground(for: themeManager.isDarkMode))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent(for: themeManager.isDarkMode) : Color.clear, lineWidth: 2)
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