import SwiftUI
import UIKit

struct PeerDetailView: View {
    let peerId: UUID
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = PeerDetailViewModel()
    @State private var memoText = ""
    @State private var showBlockConfirm = false
    @State private var showHideConfirm = false
    @State private var memoSaved = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var body: some View {
        Group {
            if let d = vm.detail {
                Form {
                    Section("プロフィール") {
                        HStack(alignment: .top, spacing: 12) {
                            if let data = d.latestIconThumbnailData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                                    .accessibilityLabel("相手のアイコン")
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(d.summary.latestDisplayName).font(.headline)
                                if let characterName = normalized(d.latestCosplayCharacterName) {
                                    Text(characterName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let data = d.latestBusinessCardImageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityLabel("相手の名刺画像")
                        }
                        let socialLinks = socialProfileLinks(from: d)
                        if !socialLinks.isEmpty {
                            ForEach(socialLinks) { link in
                                LabeledContent(link.label) {
                                    Link(destination: link.url) {
                                        HStack(spacing: 4) {
                                            Text(link.displayValue)
                                            Image(systemName: "arrow.up.forward.app")
                                                .imageScale(.small)
                                        }
                                    }
                                    .accessibilityHint("\(link.label)のユーザーページを開きます")
                                }
                            }
                        }
                        let importedLinks = importedContactLinks(
                            from: vm.contactLinks,
                            excluding: Set(socialLinks.map { $0.url.absoluteString.lowercased() })
                        )
                        if !importedLinks.isEmpty {
                            ForEach(importedLinks) { link in
                                LabeledContent(link.label) {
                                    Link(destination: link.url) {
                                        HStack(spacing: 4) {
                                            Text(link.displayValue)
                                            Image(systemName: "arrow.up.forward.app")
                                                .imageScale(.small)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section("交換日・タグ") {
                        LabeledContent("初回の交換") {
                            Text(Self.dateFormatter.string(from: d.firstMetAt))
                        }
                        LabeledContent("最後の交換") {
                            Text(Self.dateFormatter.string(from: d.lastMetAt))
                        }
                        if let tag = d.lastEventTag, !tag.isEmpty {
                            LabeledContent("イベントタグ") {
                                Text(tag)
                            }
                        }
                    }
                    if !d.exchangeSessions.isEmpty {
                        Section("交換履歴") {
                            ForEach(d.exchangeSessions) { row in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Self.dateFormatter.string(from: row.startedAt))
                                        .font(.subheadline.weight(.medium))
                                    Text("\(row.transport.uppercased()) ・ \(ExchangeState(rawValue: row.state)?.localizedLabel ?? row.state)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let r = row.result {
                                        Text("結果: \(r)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let fr = row.failureReason, !fr.isEmpty {
                                        Text("理由: \(fr)")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.danger)
                                    }
                                }
                            }
                        }
                    }
                    Section("メモ") {
                        TextField("メモ", text: $memoText, axis: .vertical)
                            .lineLimit(3 ... 8)
                            .onChange(of: memoText) { _, _ in memoSaved = false }
                        HStack {
                            Button("メモを保存") {
                                Task {
                                    await vm.saveMemo(memoText)
                                    memoSaved = true
                                }
                            }
                            if memoSaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.default, value: memoSaved)
                    }
                    Section {
                        if d.summary.isBlocked {
                            Button("ブロック解除") {
                                Task { await vm.toggleBlock() }
                            }
                        } else {
                            Button("ブロック", role: .destructive) {
                                showBlockConfirm = true
                            }
                        }
                        if d.summary.isHidden {
                            Button("表示に戻す") {
                                Task { await vm.toggleHidden() }
                            }
                        } else {
                            Button("非表示にする") {
                                showHideConfirm = true
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("詳細")
        .confirmationDialog("この相手をブロックしますか？", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("ブロック", role: .destructive) {
                Task { await vm.toggleBlock() }
            }
        } message: {
            Text("ブロックすると、この相手からの交換リクエストが自動で拒否されます。")
        }
        .confirmationDialog("この相手を非表示にしますか？", isPresented: $showHideConfirm, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                Task { await vm.toggleHidden() }
            }
        } message: {
            Text("非表示にすると履歴一覧に表示されなくなりますが、データは保持されます。")
        }
        .task {
            vm.attach(env)
            await vm.load(peerId: peerId)
            memoText = vm.detail?.summary.memo ?? ""
        }
    }

    private struct SocialProfileLink: Identifiable {
        var id: String
        var service: SNSUserID.Service?
        var label: String
        var displayValue: String
        var url: URL
    }

    private struct ImportedContactLink: Identifiable {
        var id: UUID
        var label: String
        var displayValue: String
        var url: URL
    }

    private func socialProfileLinks(from detail: PeerDetail) -> [SocialProfileLink] {
        var links: [SocialProfileLink] = []
        let serviceValues: [(SNSUserID.Service, String?)] = [
            (.x, detail.latestTwitterURL),
            (.instagram, detail.latestInstagramURL),
            (.tiktok, detail.latestTiktokURL),
        ]

        for (service, rawValue) in serviceValues {
            if let link = socialProfileLink(label: SNSUserID.displayName(for: service), rawValue: rawValue, forcedService: service) {
                links.append(link)
            }
        }

        if let legacyLink = socialProfileLink(label: detail.latestSNSLabel, rawValue: detail.latestSNSURL),
           legacyLink.service.map({ service in links.contains { $0.service == service } }) != true
        {
            links.append(legacyLink)
        }

        return links
    }

    private func socialProfileLink(label: String?, rawValue: String?) -> SocialProfileLink? {
        socialProfileLink(label: label, rawValue: rawValue, forcedService: nil)
    }

    private func socialProfileLink(
        label: String?,
        rawValue: String?,
        forcedService: SNSUserID.Service?
    ) -> SocialProfileLink? {
        let service = forcedService ?? SNSUserID.service(label: label, rawValue: rawValue)
        guard let url = SNSUserID.profileURL(rawValue, service: service) else { return nil }
        let displayValue = SNSUserID.display(rawValue, service: service) ?? url.absoluteString
        let resolvedLabel: String
        if let service {
            resolvedLabel = SNSUserID.displayName(for: service)
        } else {
            let trimmed = label?.trimmedCoscard() ?? ""
            resolvedLabel = trimmed.isEmpty ? "SNS" : trimmed
        }
        let id = service.map { SNSUserID.displayName(for: $0) } ?? "\(resolvedLabel)-\(url.absoluteString)"
        return SocialProfileLink(id: id, service: service, label: resolvedLabel, displayValue: displayValue, url: url)
    }

    private func importedContactLinks(
        from links: [ContactLinkSummary],
        excluding existingURLKeys: Set<String>
    ) -> [ImportedContactLink] {
        var seen = existingURLKeys
        var result: [ImportedContactLink] = []
        for link in links {
            guard let rawURL = link.normalizedURL,
                  let url = URL(string: rawURL)
            else { continue }
            let key = url.absoluteString.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(ImportedContactLink(
                id: link.id,
                label: link.platform.displayName,
                displayValue: link.usernameCandidate ?? rawURL,
                url: url
            ))
        }
        return result
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        PeerDetailView(peerId: UUID())
            .environmentObject(AppEnvironment.preview)
    }
}
