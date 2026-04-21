import Foundation

@MainActor
struct LoadInitialStateUseCase {
    let profileRepository: ProfileRepositoryProtocol

    /// プロフィールが存在すれば `true`
    func execute() async throws -> Bool {
        let p = try await profileRepository.fetchCurrentProfile()
        return p != nil
    }
}
