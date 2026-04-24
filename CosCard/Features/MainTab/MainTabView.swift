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
            await syncExchangeMode()
        }
    }

    private func syncExchangeMode() async {
        switch selectedTab {
        case .exchange:
            let profile = try? await env.profileRepository.fetchCurrentProfile()
            let displayName = profile?.displayName ?? "Guest"
            try? await StartExchangeUseCase(nearby: env.nearby).execute(displayName: displayName)
        case .myCard, .history:
            await StopExchangeUseCase(nearby: env.nearby).execute()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppEnvironment.preview)
}
