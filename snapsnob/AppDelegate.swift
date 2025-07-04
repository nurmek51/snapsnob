import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Lock the entire app to portrait orientation on all devices (iPhone & iPad).
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
} 