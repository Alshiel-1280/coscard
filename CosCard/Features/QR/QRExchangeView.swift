import SwiftUI
import UIKit

struct QRExchangeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = QRExchangeViewModel()
    @State private var cameraDenied = false

    var body: some View {
        Form {
            Section {
                Text("MPC が不安定なときのフォールバック。相手がこの画面で表示したQRをスキャンするとプロフィールを保存します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("自分のQR") {
                if let img = vm.qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("自分のプロフィール交換用QRコード")
                } else {
                    Text("「QRを更新」で生成")
                        .foregroundStyle(.secondary)
                }
                if !vm.payloadSummary.isEmpty {
                    Text(vm.payloadSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("QRを更新") {
                    Task { await vm.prepareMyQR() }
                }
            }
            Section("相手のQRを読み取る") {
                Button("カメラでスキャン") {
                    cameraDenied = false
                    vm.showScanner = true
                }
                if cameraDenied {
                    Text("カメラが使えません。設定で CosCard のカメラを許可してください。")
                        .font(.caption)
                        .foregroundStyle(AppColors.danger)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            if let ok = vm.scanSuccessMessage {
                Section {
                    Text(ok)
                        .foregroundStyle(.green)
                }
            }
            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(AppColors.danger)
                }
            }
        }
        .navigationTitle("QR 交換")
        .task {
            vm.attach(env)
            await vm.prepareMyQR()
        }
        .sheet(isPresented: $vm.showScanner) {
            QRScannerView(
                onScan: { code in
                    Task { await vm.handleScannedBase64(code) }
                },
                isPresented: $vm.showScanner,
                cameraDenied: $cameraDenied
            )
        }
        .sheet(isPresented: $vm.showScanComplete) {
            NavigationStack {
                ExchangeCompleteView(peerName: vm.pendingScanPeerName) { memo, tag in
                    Task {
                        await vm.finalizeScan(memo: memo, eventTag: tag)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            vm.discardPendingScan()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        QRExchangeView()
            .environmentObject(AppEnvironment.preview)
    }
}
