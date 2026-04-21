import Foundation

@MainActor
final class LaunchViewModel: ObservableObject {
    @Published private(set) var isReady = false

    func finishLaunch() {
        isReady = true
    }
}
