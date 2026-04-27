# CosCard（仮）

iPhone 同士でオフライン近距離プロフィール交換を行う iOS アプリの MVP。**iOS 17+** / SwiftUI / SwiftData / MultipeerConnectivity。  
リポジトリルート: `cursor/coscard`（この README と同階層に `CosCard/`・`project.yml`）。

---

## すぐ再開する（次のチャット用）

1. **前提**: Xcode インストール済み、必要なら `brew install xcodegen`。
2. **生成と起動**:
   ```bash
   cd /Users/ryo1280/cursor/coscard
   xcodegen generate
   open CosCard.xcodeproj
   ```
3. **実装の入口**（交換フローの中心）:
   - UI: `CosCard/Features/Exchange/ExchangeModeView.swift`, `ExchangeViewModel.swift`
   - 近傍: `CosCard/DataLayer/Nearby/MPCManager.swift`, `MPCMessageEncoder.swift`
   - 保存: `CosCard/Application/UseCases/SaveExchangeResultUseCase.swift`
   - ドメイン: `CosCard/Domain/Models/WireMessage.swift`, `ExchangeState.swift`
4. **未着手の洗い出し**: リポジトリ内で `TODO` を検索（例: `rg TODO CosCard`）。
5. **詳細な実装メモ**: [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md)

---

## セットアップ

1. [XcodeGen](https://github.com/yonaskolb/XcodeGen) をインストール（例: `brew install xcodegen`）。
2. プロジェクトルートで:

```bash
cd coscard
xcodegen generate
open CosCard.xcodeproj
```

3. **実機**の場合は Xcode の **Signing & Capabilities** で開発チームを設定。  
4. **`project.yml`** の `DEVELOPMENT_TEAM` は空のまま。チーム ID を入れる場合はここか Xcode 側で設定。

---

## ディレクトリ名（Data → DataLayer）

ワークスペースの `.cursorignore` に `data/` があるため、仕様上の `CosCard/Data` は **`CosCard/DataLayer`** にしている（`Persistence` / `Nearby` / `Security` の構成は同じ）。Swift の import には影響しない。

---

## アーキテクチャ（概要）

| 層 | 役割 |
|----|------|
| `App/` | `CosCardApp`, `RootView`, `AppEnvironment`（DI） |
| `Features/` | View + ViewModel（SwiftUI / MVVM） |
| `Application/UseCases/` | ユースケース |
| `Domain/` | モデル・リポジトリプロトコル（Entity は View に渡さない方針） |
| `DataLayer/` | SwiftData Entity / Repository、MPC、Keychain スタブ |
| `Shared/` | デザイン、拡張、`LocalPeerKey`、`Checksum` など |

近傍通信の実装は **`DataLayer/Nearby`** に閉じる。ワイヤ形式は **`WireEnvelope` + `WireMessageType` + Payload**（`Domain/Models/WireMessage.swift`）。

---

## 現在の実装状況

### 入っているもの

- **起動**: 初回はオンボーディング、プロフィール作成後は **`MainTabView`（TabView）**。
- **ナビ**: フッタータブで **マイカード・交換・履歴**。マイカード右上の歯車から **設定**（ブロックリスト・通知・トークン削除・プライバシーポリシー・利用規約）。
- **プロフィール**: 作成・編集（`ProfileEdit`）、`MyCardView` でマイカード表示。
- **交換モード**: MPC で候補一覧 → 招待（`exchangeId` は SwiftData のセッション ID と共通）。
- **交換フロー（MVP）**:
  1. セッション接続後、**発信側**が 4 桁コードを送信（`onSessionConnected`）。
  2. 双方が同じコードを目視確認し **「確認して承認する」** で `approvalState`。
  3. 双方承認後、短命トークン付き **軽量プロフィール** を送受信。
  4. **完了シート**でメモ・イベントタグを任意入力 → `SaveExchangeResultUseCase` で `LocalPeerKey` 算出、`PeerContact` upsert、`LightweightProfileSnapshot`、`ExchangeSession` 完了。
- **履歴・詳細**: 一覧、アイコン・SNS・交換日・イベントタグ・セッション履歴、メモ、ブロック / 非表示（SwiftData）。
- **QR**: Base64 `WireEnvelope` 生成・スキャン（AVFoundation）、完了シートでメモ/タグ入力、トークン・期限検証、カメラ拒否時の案内。
- **安定プロフィール ID**: `publicProfileId`（初回 `ensurePublicProfileId` で永続化）と `LocalPeerKey` の整理。
- **権限**: `NSLocalNetworkUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSCameraUsageDescription`, **`NSBonjourServices`**: `_coscard._tcp`（近傍探索用）。

### 粗い / 今後（コード内 `TODO` 参照）

- `InvitePayload` に安定 ID を載せたブロック照合の強化。
- `ResolveDuplicateExchangeUseCase` のユーザー選択 UX。
- `KeychainStore` の SecItem 実装、`schemaVersion` マイグレーション本実装。

---

## 今後のプラン（優先度の目安）

1. **招待ワイヤ拡張** — `publicProfileId` とブロックリストの照合（表示名以外）。
2. **重複交換 UX** — `ResolveDuplicateExchangeUseCase` で更新/スキップの選択。
3. **Keychain** — 長期シークレットが必要になった段階で実装。
4. **QR 画像** — サムネイル載せる場合のペイロードサイズ上限と圧縮。

（[`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md) に詳細あり。）

---

## ビルド・テスト

```bash
xcodegen generate
xcodebuild -scheme CosCard -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CosCard -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CosCardTests
```

- **Simulator 名**は環境に合わせて変更（`xcrun simctl list devices`）。
- CI や一部環境では `CoreSimulator` 未導入などで `xcodebuild` が失敗することがある。**ローカル Xcode でのビルド成功を正**とする。

---

## 参考（仕様の原本）

- プロジェクト名・画面一覧・Wire 仕様・トークン規則などは、依頼時の仕様書（CosCard MVP）に準拠。  
- 変更時は `schemaVersion` / `transport` / `profileVersion` をワイヤと SwiftData の両方で意識すること。
