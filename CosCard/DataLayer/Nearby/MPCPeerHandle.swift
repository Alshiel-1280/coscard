import Foundation
import MultipeerConnectivity

/// MCPeerID を候補キーとして扱うための薄いラッパ。
/// MPCManager はプロフィール表示名ではなく端末固有の displayName を使うため、
/// 同名ユーザー同士でも候補キーが衝突しない。
enum MPCPeerHandle {
    static func candidateKey(for peer: MCPeerID) -> String {
        peer.displayName
    }
}
