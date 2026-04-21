import Foundation
import MultipeerConnectivity

/// MCPeerID を候補キーとして扱うための薄いラッパ。
enum MPCPeerHandle {
    static func candidateKey(for peer: MCPeerID) -> String {
        peer.displayName
    }
}
