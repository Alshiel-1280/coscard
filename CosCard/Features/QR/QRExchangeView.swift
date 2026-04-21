import SwiftUI

struct QRExchangeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = QRExchangeViewModel()

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
                    vm.showScanner = true
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
                isPresented: $vm.showScanner
            )
        }
    }
}

#Preview {
    NavigationStack {
        QRExchangeView()
            .environmentObject(AppEnvironment.preview)
    }
}
