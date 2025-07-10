import SwiftUI
import FirebaseAnalytics

@main
struct SnapsnobApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var photoManager = PhotoManager()
    @StateObject private var aiAnalysisManager: AIAnalysisManager
    @StateObject private var fullScreenPhotoManager = FullScreenPhotoManager()
    @StateObject private var themeManager = ThemeManager()
    
    init() {
        let photoManager = PhotoManager()
        let aiAnalysisManager = AIAnalysisManager(photoManager: photoManager)
        _photoManager = StateObject(wrappedValue: photoManager)
        _aiAnalysisManager = StateObject(wrappedValue: aiAnalysisManager)
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .onAppear {
                        print("[Analytics] custom_app_open event sent")
                        Analytics.logEvent("custom_app_open", parameters: [
                            "timestamp": Date().timeIntervalSince1970
                        ])
                    }
                    .environmentObject(photoManager)
                    .environmentObject(aiAnalysisManager)
                    .environmentObject(fullScreenPhotoManager)
                    .environmentObject(themeManager)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                        // Clear caches when system is low on memory
                        print("⚠️ Memory warning received - clearing image caches")
                        photoManager.clearImageCaches()
                    }
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
