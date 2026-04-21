import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MyCardView()
            }
            .tabItem {
                Label("マイカード", systemImage: "person.crop.rectangle")
            }

            NavigationStack {
                ExchangeModeView()
            }
            .tabItem {
                Label("交換", systemImage: "arrow.triangle.2.circlepath")
            }

            NavigationStack {
                HistoryListView()
            }
            .tabItem {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppEnvironment.preview)
}
