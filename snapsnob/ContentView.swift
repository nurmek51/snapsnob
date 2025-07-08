import SwiftUI

struct ContentView: View {
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Global background fills the entire screen on all devices
            AppColors.background(for: themeManager.isDarkMode)
                .ignoresSafeArea()

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
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
        // Present single photo in a fullscreen cover so that it sits above the TabView (hiding the tab bar)
        .fullScreenCover(
            item: Binding<Photo?>(
                get: { fullScreenPhotoManager.selectedPhoto },
                set: { fullScreenPhotoManager.selectedPhoto = $0 }
            )
        ) { photo in
            FullScreenPhotoView(photo: photo, photoManager: photoManager) {
                withAnimation(AppAnimations.modal) {
                    fullScreenPhotoManager.selectedPhoto = nil
                }
            }
            .presentationBackground(.clear)
        }
        // Present story-style series using a simple overlay so it stays above everything while
        // still allowing a custom transition.
        .overlay {
            if let series = fullScreenPhotoManager.selectedSeries {
                EnhancedStoryView(
                    photoSeries: series,
                    photoManager: photoManager
                ) {
                    withAnimation(AppAnimations.modal) {
                        fullScreenPhotoManager.selectedSeries = nil
                    }
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
    }
}

#Preview {
    ContentView()
}
