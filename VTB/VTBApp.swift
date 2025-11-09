
import SwiftUI
import CoreData

@main
struct VTBApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .onOpenURL { url in

                        handleOAuthCallback(url: url)
                    }
                    .task {

                        await requestNotificationAuthorization()
                    }
            }
        }
    }

    private func requestNotificationAuthorization() async {

        let hasRequestedNotifications = UserDefaults.standard.bool(forKey: "hasRequestedNotifications")
        if !hasRequestedNotifications {
            let granted = await NotificationManager.shared.requestAuthorization()
            UserDefaults.standard.set(true, forKey: "hasRequestedNotifications")

            if granted {
                print("Разрешение на уведомления предоставлено")
            } else {
                print("Разрешение на уведомления отклонено")
            }
        }
    }

    private func handleOAuthCallback(url: URL) {

    }
}
