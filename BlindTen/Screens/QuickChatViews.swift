import SwiftUI

enum QuickChatSettings {
    /// UserDefaults key: show other players' phrases (on by default).
    static let showOthersKey = "quickChat.showOthers"
}

/// Suggested phrases for the moment as chips, plus "More" with all of them.
/// Only preset phrases can be sent (SPEC.md: no free-text chat).
struct QuickChatBar: View {
    let context: QuickChat.Context
    /// Highlights a picked phrase (duel summary); nil sends right away.
    var selected: String?
    let send: (String) -> Void
    @State private var showsAll = false
    @State private var lastSent: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickChat.suggestions(for: context), id: \.self) { id in
                    chip(id)
                }
                Button {
                    showsAll = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.heavy))
                        .frame(width: 44, height: 40)
                        .background(Theme.surface, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text("More phrases"))
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
        .sheet(isPresented: $showsAll) {
            QuickChatSheet { id in
                pick(id)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lastSent)
    }

    private func chip(_ id: String) -> some View {
        let isSelected = selected == id
        return Button {
            pick(id)
        } label: {
            Text(verbatim: QuickChat.text(for: id) ?? "")
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)
                .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func pick(_ id: String) {
        lastSent = id
        send(id)
    }
}

/// All phrases, grouped.
struct QuickChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    let send: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(QuickChat.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(Theme.secondaryText)
                            FlowLayout(spacing: 8) {
                                ForEach(QuickChat.phrases.filter { $0.category == category }) { phrase in
                                    Button {
                                        send(phrase.id)
                                        dismiss()
                                    } label: {
                                        Text(verbatim: QuickChat.text(for: phrase.id) ?? "")
                                            .font(.headline.weight(.bold))
                                            .padding(.horizontal, 14)
                                            .frame(height: 40)
                                            .background(Theme.surface, in: Capsule())
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(Theme.primaryText)
            .navigationTitle("Quick chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Phrases as bubbles that pop in and fade out after a few seconds.
struct QuickChatBubbles: View {
    let feed: QuickChatFeed
    let player: (String) -> Player?
    let me: Player.ID?
    @AppStorage(QuickChatSettings.showOthersKey) private var showOthers = true
    @State private var now = ProcessInfo.processInfo.systemUptime

    var body: some View {
        let messages = feed.visible(at: now).filter { showOthers || $0.senderID == me?.uuidString }
        VStack(spacing: 8) {
            ForEach(messages) { message in
                let sender = player(message.senderID)
                HStack(spacing: 8) {
                    Text(verbatim: sender?.emoji ?? "")
                    Text(verbatim: QuickChat.text(for: message.phraseID) ?? "")
                        .font(.headline.weight(.heavy))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(message.senderID == me?.uuidString ? Theme.onAccent : Theme.primaryText)
                .background(
                    message.senderID == me?.uuidString ? Theme.accent : Theme.surface,
                    in: Capsule()
                )
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(Motion.snappy, value: messages.map(\.id))
        .allowsHitTesting(false)
        .onChange(of: feed.messages.last?.id) {
            now = ProcessInfo.processInfo.systemUptime
        }
        .task(id: feed.messages.last?.id) {
            // One wait until the newest bubble is due, not a ticking timer.
            try? await Task.sleep(for: .seconds(QuickChatFeed.lifetime))
            now = ProcessInfo.processInfo.systemUptime
        }
    }
}

extension QuickChat.Category {
    var title: LocalizedStringKey {
        switch self {
        case .greeting: "Hello"
        case .hype: "Hype"
        case .praise: "Praise"
        case .sympathy: "Sympathy"
        case .selfTalk: "About me"
        case .taunt: "Friendly trash talk"
        case .end: "Game over"
        case .emoji: "Emoji"
        }
    }
}

/// Lays out views in rows, wrapping like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
