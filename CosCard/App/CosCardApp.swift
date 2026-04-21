import SwiftData
import SwiftUI

@main
struct CosCardApp: App {
    private let container: ModelContainer
    @StateObject private var appEnvironment: AppEnvironment

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainerProvider.makeContainer()
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
        container = c
        let ctx = ModelContext(c)
        _appEnvironment = StateObject(wrappedValue: AppEnvironment(modelContext: ctx))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment)
                .modelContainer(container)
        }
    }
}
