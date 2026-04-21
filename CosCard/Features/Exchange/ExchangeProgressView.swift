import SwiftUI

struct ExchangeProgressView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("交換中")
    }
}

#Preview {
    NavigationStack {
        ExchangeProgressView(message: "相手の承認を待っています…")
    }
}
