
import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            DashboardView(context: viewContext)
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
            }

            AccountsView()
                .tabItem {
                    Label("Счета", systemImage: "creditcard.fill")
        }

            BudgetView(context: viewContext)
                .tabItem {
                    Label("Бюджет", systemImage: "chart.pie.fill")
            }

            ForecastingView(context: viewContext)
                .tabItem {
                    Label("Прогноз", systemImage: "chart.line.uptrend.xyaxis")
            }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
