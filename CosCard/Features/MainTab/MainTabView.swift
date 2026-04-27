import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: Tab = .myCard

    private enum Tab: Hashable {
        case myCard
        case exchange
        case history
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MyCardView()
            }
            .tag(Tab.myCard)
            .tabItem {
                Label("マイカード", systemImage: "person.crop.rectangle")
            }

            NavigationStack {
                ExchangeModeView()
            }
            .tag(Tab.exchange)
            .tabItem {
                Label("交換", systemImage: "arrow.triangle.2.circlepath")
            }

            NavigationStack {
                HistoryListView()
            }
            .tag(Tab.history)
            .tabItem {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }
        }
        .task(id: selectedTab) {
            await stopExchangeIfNeeded()
        }
    }

    private func stopExchangeIfNeeded() async {
        if selectedTab != .exchange {
            await StopExchangeUseCase(nearby: env.nearby).execute()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppEnvironment.preview)
}
