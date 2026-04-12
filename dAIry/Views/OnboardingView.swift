import SwiftUI

struct OnboardingView: View {

    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    let permissionManager: PermissionManaging
    let locationTracker: LocationTracker
    let onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var photoStatus: AuthorizationStatus?
    @State private var healthStatus: AuthorizationStatus?
    @State private var locationRequested: Bool = false
    @State private var isRequesting: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            switch currentStep {
            case 0: welcomeStep
            case 1:
                permissionStep(icon: "photo.on.rectangle.angled", title: "Photo Library",
                    description: "dAIry uses your photos to include visual memories in your diary entries.",
                    status: photoStatus)
            case 2:
                permissionStep(icon: "heart.text.square", title: "Health Data",
                    description: "dAIry reads your step count, distance, and active energy to capture your daily activity.",
                    status: healthStatus)
            case 3:
                permissionStep(icon: "location.fill", title: "Location",
                    description: "dAIry tracks the places you visit throughout the day to add context to your diary entries.",
                    status: locationRequested ? .authorized : nil)
            case 4: apiKeyStep
            default: EmptyView()
            }
            Spacer()
            bottomButton
            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 32)
        .multilineTextAlignment(.center)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.fill").font(.system(size: 64)).foregroundStyle(.blue)
            Text("Welcome to dAIry").font(.largeTitle.bold())
            Text("Your AI-powered daily diary. dAIry collects photos, health data, and location to write a personal narrative of your day.")
                .font(.body).foregroundStyle(.secondary)
        }
    }

    private func permissionStep(icon: String, title: String, description: String, status: AuthorizationStatus?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(.blue)
            Text(title).font(.title.bold())
            Text(description).font(.body).foregroundStyle(.secondary)
            if let status { statusView(for: status, source: dataSourceForStep) }
        }
    }

    private var apiKeyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill").font(.system(size: 56)).foregroundStyle(.blue)
            Text("Gemini API Key").font(.title.bold())
            Text("dAIry uses Google Gemini to generate your diary entries. You'll need to provide your own API key.")
                .font(.body).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusView(for status: AuthorizationStatus, source: DataSource) -> some View {
        switch status {
        case .authorized:
            Label("Access Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
        case .denied, .revoked:
            VStack(spacing: 8) {
                Label("Access Denied", systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.headline)
                Text(PermissionManager.denialMessage(for: source)).font(.footnote).foregroundStyle(.secondary)
            }
        case .notDetermined: EmptyView()
        }
    }

    private var dataSourceForStep: DataSource {
        switch currentStep {
        case 1: return .photos
        case 2: return .healthKit
        case 3: return .location
        default: return .photos
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch currentStep {
        case 0:
            Button { currentStep = 1 } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large)
        case 1:
            if photoStatus == nil {
                requestButton(title: "Allow Photo Access") { photoStatus = await permissionManager.requestPhotoAccess() }
            } else { continueButton { currentStep = 2 } }
        case 2:
            if healthStatus == nil {
                requestButton(title: "Allow Health Access") { healthStatus = await permissionManager.requestHealthKitAccess() }
            } else { continueButton { currentStep = 3 } }
        case 3:
            if !locationRequested {
                Button {
                    locationTracker.requestPermission()
                    locationRequested = true
                } label: {
                    Text("Allow Location Access").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
            } else { continueButton { currentStep = 4 } }
        case 4:
            VStack(spacing: 12) {
                Button { completeOnboarding() } label: {
                    Text("Configure in Settings").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                Button { completeOnboarding() } label: {
                    Text("Skip for Now").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).controlSize(.large)
            }
        default: EmptyView()
        }
    }

    private func requestButton(title: String, action: @escaping () async -> Void) -> some View {
        Button {
            isRequesting = true
            Task { await action(); isRequesting = false }
        } label: {
            HStack {
                Text(title)
                if isRequesting { ProgressView().padding(.leading, 4) }
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(isRequesting)
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Text("Continue").frame(maxWidth: .infinity)
        }.buttonStyle(.borderedProminent).controlSize(.large)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        onComplete()
    }
}
