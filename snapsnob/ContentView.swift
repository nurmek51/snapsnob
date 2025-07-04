import SwiftUI

struct ContentView: View {
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Дом")
                }
            
            CategoriesView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Категории")
                }
            
            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Избранные")
                }
        }
        .accentColor(AppColors.accent(for: themeManager.isDarkMode))
        .background(AppColors.background(for: themeManager.isDarkMode))
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        // Full-screen presentation is now handled inside individual detail views
        // (AlbumDetailView, CategoryDetailView, etc.) so that any currently
        // presented sheets remain visible behind the fullscreen photo.
    }
}

#Preview {
    ContentView()
}
