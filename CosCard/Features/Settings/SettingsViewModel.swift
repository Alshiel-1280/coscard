import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var cacheClearResultMessage: String?
    @Published var showResultAlert = false

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func clearExpiredTokens() async {
        guard let env else { return }
        do {
            try await env.tokenRepository.pruneExpired()
            cacheClearResultMessage = "期限切れの交換トークンを削除しました。"
        } catch {
            cacheClearResultMessage = "削除に失敗しました。"
        }
        showResultAlert = true
    }
}
