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

    init() {
        // Если онбординг завершён, инициализируем менеджеры сразу
        if OnboardingManager.shared.hasCompletedOnboarding {
            let pm = PhotoManager()
            let ai = AIAnalysisManager(photoManager: pm)
            _photoManager = State(initialValue: pm)
            _aiAnalysisManager = State(initialValue: ai)
        }
    }

    var body: some Scene {
        WindowGroup {
            if onboardingManager.hasCompletedOnboarding, let photoManager, let aiAnalysisManager {
                ContentView()
                    .environmentObject(photoManager)
                    .environmentObject(aiAnalysisManager)
                    .environmentObject(fullScreenPhotoManager)
                    .environmentObject(themeManager)
                    .environmentObject(localizationManager)
                    .environmentObject(onboardingManager)
            } else {
                OnboardingView(onFinish: {
                    let pm = PhotoManager()
                    let ai = AIAnalysisManager(photoManager: pm)
                    self.photoManager = pm
                    self.aiAnalysisManager = ai
                    onboardingManager.hasCompletedOnboarding = true
                })
                .environmentObject(themeManager)
                .environmentObject(onboardingManager)
            }
        }
    }
}

struct AppCoordinator: View {
    @EnvironmentObject var photoManager: PhotoManager
    @EnvironmentObject var aiAnalysisManager: AIAnalysisManager
    @State private var didApplyCache = false  // Prevents multiple applications

    var body: some View {
        ContentView()
            .onAppear { tryApplyCacheIfReady() }
            .onChange(of: photoManager.isLoading) { _ in tryApplyCacheIfReady() }
            .onChange(of: aiAnalysisManager.cacheLoaded) { _ in tryApplyCacheIfReady() }
    }

    private func tryApplyCacheIfReady() {
        guard !didApplyCache,                    // Haven't applied yet
              !photoManager.isLoading,           // Photos are loaded
              !photoManager.allPhotos.isEmpty,   // Photos actually exist
              aiAnalysisManager.cacheLoaded      // Cache is loaded
        else { return }
        aiAnalysisManager.applyCacheIfAvailable()
        didApplyCache = true  // Prevent future applications
    }
}
