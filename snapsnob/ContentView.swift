import SwiftUI

struct ContentView: View {
    @EnvironmentObject var fullScreenPhotoManager: FullScreenPhotoManager
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager

    var body: some View {
        ZStack {
            // Global background fills the entire screen on all devices
            AppColors.background(for: themeManager.isDarkMode)
                .ignoresSafeArea()

            Group {
                if DeviceInfo.shared.isIPad {
                    // Centered, width-limited container for iPad
                    HStack {
                        Spacer(minLength: 0)
                        TabView {
                            HomeView()
                                .tabItem {
                                    Image(systemName: "house.fill")
                                    Text("navigation.home".localized)
                                }
                            CategoriesView()
                                .tabItem {
                                    Image(systemName: "square.grid.2x2")
                                    Text("navigation.categories".localized)
                                }
                            FavoritesView()
                                .tabItem {
                                    Image(systemName: "heart.fill")
                                    Text("navigation.favorites".localized)
                                }
                            EnhancedVideoView()
                                .tabItem {
                                    Image(systemName: "video.fill")
                                    Text("Video")
                                }
                        }
                        .frame(maxWidth: 700) // You can adjust maxWidth for iPad look
                        .padding(.horizontal, 32)
                        .accentColor(AppColors.accent(for: themeManager.isDarkMode))
                        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                        Spacer(minLength: 0)
                    }
                } else {
                    // iPhone: original layout
                    TabView {
                        HomeView()
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("navigation.home".localized)
                            }
                        CategoriesView()
                            .tabItem {
                                Image(systemName: "square.grid.2x2")
                                Text("navigation.categories".localized)
                            }
                        FavoritesView()
                            .tabItem {
                                Image(systemName: "heart.fill")
                                Text("navigation.favorites".localized)
                            }
                        EnhancedVideoView()
                            .tabItem {
                                Image(systemName: "video.fill")
                                Text("Video")
                            }
                    }
                    .accentColor(AppColors.accent(for: themeManager.isDarkMode))
                    .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                }
            }
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
        // Onboarding overlay (appears above everything else)
        // (Удалено, теперь онбординг показывается в App.swift)
    }
}

#Preview {
    ContentView()
}
