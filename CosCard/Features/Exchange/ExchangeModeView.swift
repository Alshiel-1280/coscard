import SwiftUI

struct ExchangeModeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = ExchangeViewModel()

    private var isExchangeInProgress: Bool {
        vm.sessionEntityId != nil && !vm.showExchangeComplete
    }

    var body: some View {
        List {
            Section {
                Text("状態: \(vm.exchangeState.localizedLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("交換の状態、\(vm.exchangeState.localizedLabel)")
            }
            if let code = vm.confirmationCode {
                Section("確認コード（双方で一致を確認）") {
                    Text(code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("確認コード、\(code.map(String.init).joined(separator: " "))")
                    Text("目視で同じ4桁であることを確認してから承認してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !vm.localUserApproved {
                        Button("確認して承認する") {
                            Task { await vm.userConfirmAndApprove() }
                        }
                    } else if !vm.peerHasApproved {
                        Text("相手の承認を待っています…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if vm.hasSentMyProfile, vm.receivedPeerProfile == nil {
                Section {
                    ProgressView("相手のプロフィールを受信中…")
                }
            }
            if isExchangeInProgress {
                Section {
                    Button("交換をキャンセル", role: .cancel) {
                        Task { await vm.cancelActiveExchange() }
                    }
                }
            }
            if !isExchangeInProgress {
                Section("近くの候補") {
                    if vm.candidates.isEmpty {
                        Text("見つかりません。双方がこの画面を開いてください。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.candidates) { c in
                            NavigationLink(value: c) {
                                ExchangeCandidateRow(candidate: c)
                            }
                        }
                    }
                }
            }
            Section {
                Text("この画面を開くと探索は自動で開始されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(AppColors.danger)
                    Button("再試行") {
                        Task { await vm.retryExchange() }
                    }
                }
            }
            Section {
                NavigationLink("QR で交換（フォールバック）") {
                    QRExchangeView()
                }
            }
        }
        .navigationTitle("交換モード")
        .navigationDestination(for: PeerCandidate.self) { c in
            ExchangeConfirmView(candidate: c, viewModel: vm)
        }
        .sheet(isPresented: $vm.showIncomingInviteSheet) {
            IncomingInviteView(
                previewName: vm.incomingPreviewName ?? "相手",
                onAccept: { Task { await vm.acceptInvite() } },
                onReject: { Task { await vm.rejectInvite() } }
            )
            .interactiveDismissDisabled(true)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $vm.showExchangeComplete) {
            NavigationStack {
                ExchangeCompleteView(
                    peerName: vm.receivedPeerProfile?.displayName ?? "相手",
                    peerBio: vm.receivedPeerProfile?.bioShort,
                    isDuplicateExchange: vm.receivedPeerIsDuplicate
                ) { memo, tag, duplicateChoice in
                    Task {
                        await vm.finalizeExchange(
                            memo: memo,
                            eventTag: tag,
                            duplicateChoice: duplicateChoice
                        )
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            vm.attach(env)
            Task { await vm.ensureExchangeModeEnabled() }
        }
        .onDisappear {
            vm.cancelPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coscardPeerBlockListDidChange)) { _ in
            Task { await vm.refreshInviteBlockListAsync() }
        }
    }
}

#Preview {
    ExchangeModeView()
        .environmentObject(AppEnvironment.preview)
}
