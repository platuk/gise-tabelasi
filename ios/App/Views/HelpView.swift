import SwiftUI

/// Oyunun tüm özelliklerini açıkça anlatır. Gizli özellik yoktur (App Store 2.3.1 / 5.6).
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: LocalizedStringKey, body: LocalizedStringKey)] = [
        ("help.how.title", "help.how.body"),
        ("help.controls.title", "help.controls.body"),
        ("help.auto.title", "help.auto.body"),
        ("help.assist.title", "help.assist.body"),
        ("help.bubbles.title", "help.bubbles.body"),
        ("help.respawn.title", "help.respawn.body"),
        ("help.trophy.title", "help.trophy.body"),
        ("help.characters.title", "help.characters.body"),
        ("help.chapters.title", "help.chapters.body"),
        ("help.combo.title", "help.combo.body"),
        ("help.burn.title", "help.burn.body"),
        ("help.privacy.title", "help.privacy.body"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sections[index].title)
                                .font(Theme.title(20))
                            Text(sections[index].body)
                        }
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(Text("help.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("help.done") { dismiss() }
                }
            }
        }
    }
}
