import Foundation
import SwiftUI

// MARK: - Onboarding Steps
enum OnboardingStep: Int, CaseIterable {
    case rightSwipe = 0
    case leftSwipe = 1
    case doubleTap = 2
    case storySeries = 3
    case trashBin = 4
    case privacyNotice = 5
    
    var title: String {
        switch self {
        case .rightSwipe:
            return "onboarding.rightSwipe.title".localized
        case .leftSwipe:
            return "onboarding.leftSwipe.title".localized
        case .doubleTap:
            return "onboarding.doubleTap.title".localized
        case .storySeries:
            return "onboarding.storySeries.title".localized
        case .trashBin:
            return "onboarding.trashBin.title".localized
        case .privacyNotice:
            return "onboarding.privacy.title".localized
        }
    }
    
    var description: String {
        switch self {
        case .rightSwipe:
            return "onboarding.rightSwipe.description".localized
        case .leftSwipe:
            return "onboarding.leftSwipe.description".localized
        case .doubleTap:
            return "onboarding.doubleTap.description".localized
        case .storySeries:
            return "onboarding.storySeries.description".localized
        case .trashBin:
            return "onboarding.trashBin.description".localized
        case .privacyNotice:
            return "onboarding.privacy.description".localized
        }
    }
}

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var isOnboardingActive: Bool = false
    @Published var currentStep: OnboardingStep = .rightSwipe
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "HasCompletedOnboarding")
        }
    }
    
    private init() {
        // Check if onboarding has been completed before
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HasCompletedOnboarding")
        
        // Start onboarding if not completed
        if !hasCompletedOnboarding {
            // Delay to allow app to fully load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startOnboarding()
            }
        }
    }
    
    // MARK: - Public Methods
    func startOnboarding() {
        currentStep = .rightSwipe
        isOnboardingActive = true
    }
    
    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep) else { return }
        
        if currentIndex < OnboardingStep.allCases.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = OnboardingStep.allCases[currentIndex + 1]
            }
        } else {
            completeOnboarding()
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    func skipToPrivacyNotice() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .privacyNotice
        }
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "HasCompletedOnboarding")
        startOnboarding()
    }
    
    // MARK: - Private Methods
    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.3)) {
            isOnboardingActive = false
        }
        hasCompletedOnboarding = true
    }
} 