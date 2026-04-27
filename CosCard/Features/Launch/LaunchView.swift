import SwiftUI

struct LaunchView: View {
    @ObservedObject var viewModel: LaunchViewModel

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Text("CosCard")
                    .font(.largeTitle.bold())
                ProgressView()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            viewModel.finishLaunch()
        }
    }
}

#Preview {
    LaunchView(viewModel: LaunchViewModel())
}
