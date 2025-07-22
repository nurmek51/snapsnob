import SwiftUI
import FirebaseAnalytics

@main
struct SnapsnobApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var fullScreenPhotoManager = FullScreenPhotoManager()
    @State private var photoManager: PhotoManager? = nil
    @State private var aiAnalysisManager: AIAnalysisManager? = nil
    @State private var isInitializing = true

    init() {
        // Remove heavy initialization from init - will do it async
    }

    var body: some Scene {
        WindowGroup {
            if !isInitializing && onboardingManager.hasCompletedOnboarding, 
               let photoManager, let aiAnalysisManager {
                ContentView()
                    .environmentObject(photoManager)
                    .environmentObject(aiAnalysisManager)
                    .environmentObject(fullScreenPhotoManager)
                    .environmentObject(themeManager)
                    .environmentObject(localizationManager)
                    .environmentObject(onboardingManager)
            } else if !onboardingManager.hasCompletedOnboarding {
                OnboardingView(onFinish: {
                    Task {
                        await initializeManagers()
                    }
                    onboardingManager.hasCompletedOnboarding = true
                })
                .environmentObject(themeManager)
                .environmentObject(onboardingManager)
            } else {
                // Splash screen while initializing
                SplashView()
                    .environmentObject(themeManager)
                    .task {
                        await initializeManagers()
                    }
            }
        }
    }
    
    // Async initialization for better startup performance
    @MainActor
    private func initializeManagers() async {
        // Initialize PhotoManager on background queue
        let pm = await Task.detached(priority: .userInitiated) {
            PhotoManager()
        }.value
        
        // Initialize AIAnalysisManager but don't start analysis yet
        let ai = AIAnalysisManager(photoManager: pm)
        
        // Update state on main thread
        self.photoManager = pm
        self.aiAnalysisManager = ai
        self.isInitializing = false
        
        // Start AI analysis in background after UI is loaded
        Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            await ai.loadCache()
        }
    }
}

// Simple splash screen for smooth app launch
struct SplashView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            AppColors.background(for: themeManager.isDarkMode)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.accent(for: themeManager.isDarkMode))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("general.loading".localized)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryText(for: themeManager.isDarkMode))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct AppCoordinator: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @State private var didApplyCache = false  // Prevents multiple applications

    var body: some View {
        ContentView()
            .onAppear { 
                // Delay cache application to not block UI
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    tryApplyCacheIfReady()
                }
            }
            .onChange(of: photoManager.isLoading) { _ in tryApplyCacheIfReady() }
            .onChange(of: aiAnalysisManager.cacheLoaded) { _ in tryApplyCacheIfReady() }
    }

    private func tryApplyCacheIfReady() {
        guard !didApplyCache,                    // Haven't applied yet
              !photoManager.isLoading,           // Photos are loaded
              !photoManager.allPhotos.isEmpty,   // Photos actually exist
              aiAnalysisManager.cacheLoaded      // Cache is loaded
        else { return }
        
        Task.detached(priority: .background) {
            await aiAnalysisManager.applyCacheIfAvailable()
        }
        didApplyCache = true  // Prevent future applications
    }
}
