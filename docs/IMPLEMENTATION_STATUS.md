# CosCard 実装状況（MVP 骨組み）

## 追加・変更した主なファイル

- `CosCard/App/` — `CosCardApp.swift`, `AppEnvironment.swift`, `RootView.swift`
- `CosCard/Domain/` — Models / Protocols
- `CosCard/Shared/` — DesignSystem, Extensions, Utils（`LocalPeerKey.swift`, `AppNotifications.swift` を含む）
- `CosCard/DataLayer/` — Persistence（Entities, Repositories, ModelContainer）, Nearby（MPC）, Security
- `CosCard/Application/UseCases/` — 11 UseCase
- `CosCard/Features/` — 各画面 View / ViewModel
- `CosCard/Resources/Info.plist`（`NSBonjourServices`: `_coscard._tcp`）
- `CosCardTests/` — 単体テスト（LocalPeerKey / TokenRepository / MPCMessageEncoder / ProfileValidation）
- `project.yml`, `.gitignore`, `README.md`

## 実装済み（交換フロー MVP）

- **4 桁 + 双方承認 + プロフィール**: 発信側が `onSessionConnected` でコード送信、双方が承認後に `lightweightProfile` 送受信（`expiresAt` 付き・checksum は日付を秒単位に揃えて安定化）、完了シートで `SaveExchangeResultUseCase`。
- **安定 ID**: `UserProfileEntity.publicProfileId`（`ensurePublicProfileId`）、`LightweightProfilePayload.publicProfileId`（optional・後方互換）。`LocalPeerKey` は `publicProfileId` 優先、旧ペイロードはレガシー方式（ephemeral は含めない）。
- **トークン / リプレイ**: `isTokenAlreadySeen` / `recordIncomingTokenIfNew`、`ProfileValidation.validateIncomingExchange`（期限・再利用）を MPC / QR 共通で使用。`SaveExchangeResultUseCase` は新規トークンのみ保存。
- **セッション失敗記録**: `ExchangeSessionRepository.failSession`（切断・タイムアウト・キャンセル・相手 cancel）。成功済みセッションは上書きしない。
- **MPC**: ユーザー `cancel` 後の `notConnected` で `failed` に上書きしない。広告・ブラウズ失敗時は `onPermissionError` で UI に説明。
- **交換 UI**: `ExchangeModeView` に「交換をキャンセル」「再試行」。ブロック変更は `Notification.Name.coscardPeerBlockListDidChange` で招待拒否プリケートを更新。
- **QR**: Base64 `WireEnvelope` 生成・AVFoundation スキャン、スキャン後に完了シート（メモ・イベントタグ）、同一 `exchangeId` の連続スキャン防止、カメラ拒否時の案内と設定リンク。
- **履歴詳細**: アイコン、SNS リンク、初回/最終交換日、イベントタグ、セッション履歴一覧。
- **ブロック**: 表示名正規化セットによる招待自動拒否（従来）＋詳細/ブロック一覧からの変更を交換モードに即時通知。

## 残り TODO（優先度の目安）

| 領域 | 内容 |
|------|------|
| `InvitePayload` | `publicProfileId` 等の拡張とブロック照合（表示名スプーフィング対策の強化） |
| `ResolveDuplicateExchangeUseCase` | ログ以外の UX（更新 / スキップの選択） |
| `MPCMessageEncoder` | `schemaVersion` マイグレーション本実装 |
| `KeychainStore` | SecItem による保存 |
| QR | サムネイル載せる場合のサイズ上限と `ImageResizer` 方針 |

## ビルド・テスト

```bash
xcodegen generate
xcodebuild -scheme CosCard -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CosCard -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CosCardTests
```

- **Signing**: `project.yml` の `DEVELOPMENT_TEAM` は空。実機では Xcode で設定。
- **DataLayer**: 仕様上の `Data` フォルダ名は Cursor の `data/` ignore と衝突するため `DataLayer` を使用。
