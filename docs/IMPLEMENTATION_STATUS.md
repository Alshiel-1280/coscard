# CosCard 実装状況（MVP 骨組み）

## 追加・変更した主なファイル

- `CosCard/App/` — `CosCardApp.swift`, `AppEnvironment.swift`, `RootView.swift`
- `CosCard/Domain/` — Models / Protocols
- `CosCard/Shared/` — DesignSystem, Extensions, Utils（`LocalPeerKey.swift` を含む）
- `CosCard/DataLayer/` — Persistence（Entities, Repositories, ModelContainer）, Nearby（MPC）, Security
- `CosCard/Application/UseCases/` — 11 UseCase
- `CosCard/Features/` — 各画面 View / ViewModel
- `CosCard/Resources/Info.plist`
- `project.yml`, `.gitignore`, `README.md`

## 実装済み（交換フロー MVP）

- **4 桁 + 双方承認 + プロフィール**: 発信側が `onSessionConnected` でコード送信、双方が承認後に `lightweightProfile` 送受信、完了シートで `SaveExchangeResultUseCase` が `LocalPeerKey`・Peer upsert・`LightweightProfileSnapshotEntity`・セッション完了を実行。
- **ワイヤと DB の ID 統一**: `exchangeId`（UUID）を `ExchangeSessionEntity.id` と MPC 招待コンテキストで共有。

## 未実装 TODO（コード内検索: `TODO`）

| 領域 | 内容 |
|------|------|
| `MPCManager` | 切断時の state 復帰、ブロック済み招待の自動拒否 |
| `ExchangeViewModel` | タイムアウト、重複メッセージの厳密な扱い |
| `SaveExchangeResultUseCase` | 受信トークンの追加検証、発行トークン消費タイミングの整理 |
| `ResolveDuplicateExchangeUseCase` | 重複交換の UX |
| `KeychainStore` | SecItem による保存 |
| `MPCMessageEncoder` | `schemaVersion` マイグレーション |
| `QRExchangeViewModel` | QR 生成・スキャン・ペイロード |
| `IncomingInviteView` | 専用 UI を sheet 化（現在は ExchangeModeView 内の簡易表示） |
| ブロック | `PeerRepository.isBlockedLocalPeerKey` を MPC 招待時に参照して自動拒否 |

## ビルド上の注意点

- **Signing**: `project.yml` の `DEVELOPMENT_TEAM` は空。実機では Xcode で設定。
- **XcodeGen**: ソース追加後は `xcodegen generate` を再実行（`CosCard` フォルダ一括参照のため通常は不要）。
- **DataLayer**: 仕様上の `Data` フォルダ名は Cursor の `data/` ignore と衝突するため `DataLayer` を使用。

## 次の実装順（優先度高い順）

1. **堅牢性** — 切断・タイムアウト・`cancel` の UI 反映、MPC 再接続
2. **QR フォールバック** — `Vision` / `AVFoundation`、Base64 `WireEnvelope` の受け渡し
3. **トークン** — 受信トークン検証、`pruneExpired` の定期実行、発行トークン消費の整理
4. **IncomingInviteView** — sheet 化と handler 遅延（拒否まで handler 保持の検討）
5. **ブロック連携** — 招待時に `isBlockedLocalPeerKey` で自動拒否
6. **Keychain** — `KeychainStore` 本実装
7. **`ResolveDuplicateExchangeUseCase`**
