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
                Section {
                    codeApprovalView(code)
                } header: {
                    Text("確認コード")
                }
            }
            if vm.hasSentMyProfile, vm.receivedPeerProfile == nil {
                Section {
                    ProgressView("相手のプロフィールを受信中…")
                }
            }
            if vm.hasSentMyProfile, vm.receivedPeerProfile != nil, !vm.peerAcknowledgedMyProfile {
                Section {
                    ProgressView("相手の受信確認を待っています…")
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
                    peerCosplayCharacterName: vm.receivedPeerProfile?.cosplayCharacterName,
                    peerIconData: vm.receivedPeerProfile?.iconThumbnailData,
                    peerBusinessCardImageData: vm.receivedPeerProfile?.businessCardImageData,
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

    @ViewBuilder
    private func codeApprovalView(_ code: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text(code)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("確認コード、\(code.map(String.init).joined(separator: " "))")

            Label("相手の画面と同じ4桁なら承認", systemImage: "number.square.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            approvalAction
        }
        .padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private var approvalAction: some View {
        if !vm.localUserApproved {
            Button {
                Task { await vm.userConfirmAndApprove() }
            } label: {
                Label("確認して承認する", systemImage: "checkmark.shield.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if !vm.peerHasApproved {
            Label("相手の承認を待っています…", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("双方承認済み", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ExchangeModeView()
        .environmentObject(AppEnvironment.preview)
}
