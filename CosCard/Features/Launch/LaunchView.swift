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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.finishLaunch()
            }
        }
    }
}

#Preview {
    LaunchView(viewModel: LaunchViewModel())
}
