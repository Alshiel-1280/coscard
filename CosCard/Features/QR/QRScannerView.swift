import AVFoundation
import SwiftUI
import UIKit

/// オフライン QR 読み取り（AVFoundation）
struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    @Binding var isPresented: Bool
    @Binding var cameraDenied: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(cameraDenied: $cameraDenied)
    }

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeFound = { code in
            onScan(code)
            DispatchQueue.main.async {
                isPresented = false
            }
        }
        vc.onPermissionDenied = {
            context.coordinator.markDenied()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    final class Coordinator {
        var cameraDenied: Binding<Bool>
        init(cameraDenied: Binding<Bool>) {
            self.cameraDenied = cameraDenied
        }

        func markDenied() {
            cameraDenied.wrappedValue = true
        }
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeFound: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.onPermissionDenied?()
                        self?.showDeniedPlaceholder()
                    }
                }
            }
        default:
            onPermissionDenied?()
            showDeniedPlaceholder()
        }
    }

    private func showDeniedPlaceholder() {
        let label = UILabel()
        label.text = "カメラへのアクセスがオフです。\n設定アプリから CosCard のカメラを許可してください。"
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        let button = UIButton(type: .system)
        button.setTitle("設定を開く", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }, for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupSession() {
        guard previewLayer == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            onPermissionDenied?()
            showDeniedPlaceholder()
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = obj.stringValue
        else { return }
        session.stopRunning()
        onCodeFound?(stringValue)
    }

    deinit {
        session.stopRunning()
    }
}
