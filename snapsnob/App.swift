import SwiftUI

@main
struct PhotoRatingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            ContentView()
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
