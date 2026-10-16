import SwiftUI

/// Picks an avatar from Apple's standard emoji, grouped by theme.
struct AvatarPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(AvatarCatalog.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(Theme.secondaryText)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                                ForEach(AvatarCatalog.emojis[category] ?? [], id: \.self) { emoji in
                                    Button {
                                        selection = emoji
                                        dismiss()
                                    } label: {
                                        Text(verbatim: emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 52, height: 52)
                                            .background(
                                                emoji == selection ? Theme.accent : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                    }
                                    .buttonStyle(.pressable)
                                    .accessibilityAddTraits(emoji == selection ? .isSelected : [])
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Choose your avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A big avatar that opens the picker.
struct AvatarButton: View {
    @Binding var emoji: String
    var size: CGFloat = 64
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Text(verbatim: emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(Theme.surface, in: Circle())
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(Theme.accent, Theme.background)
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text("Change avatar"))
        .sheet(isPresented: $isPicking) {
            AvatarPicker(selection: $emoji)
        }
    }
}

extension AvatarCatalog.Category {
    var title: LocalizedStringKey {
        switch self {
        case .animals: "Animals"
        case .faces: "Faces"
        case .food: "Food"
        case .fun: "Sports & fun"
        case .nature: "Nature & things"
        }
    }
}
