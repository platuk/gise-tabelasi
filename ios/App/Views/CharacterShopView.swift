import SpriteKit
import SwiftUI

/// Karakter ekranı: kazanılan kupalarla karakter açılır ve seçilir. Gerçek parayla satın alma yoktur.
struct CharacterShopView: View {
    @Binding var wallet: Int
    @Binding var unlockedStorage: String
    @Binding var selected: Int
    @Environment(\.dismiss) private var dismiss

    private var unlocked: Set<GameCharacter> { GameCharacter.unlocked(from: unlockedStorage) }
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        TrophyIcon(tier: .gold).frame(width: 30, height: 30)
                        Text("shop.wallet \(wallet)")
                            .font(Theme.title(20))
                    }
                    Text("shop.hint")
                        .font(Theme.title(14))
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(GameCharacter.allCases) { character in
                            card(for: character)
                        }
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(Text("shop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("help.done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for character: GameCharacter) -> some View {
        let isUnlocked = unlocked.contains(character)
        let isSelected = selected == character.rawValue && isUnlocked
        VStack(spacing: 8) {
            SpriteView(scene: CharacterPreviewScene(character: character, dances: isSelected), options: [.allowsTransparency])
                .frame(width: 90, height: 100)
                .opacity(isUnlocked ? 1 : 0.45)
            Text(character.name)
                .font(Theme.title(17))
            if isSelected {
                Text("shop.selected")
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.marquee)
            } else if isUnlocked {
                Button("shop.select") {
                    MenuFeedback.tap()
                    selected = character.rawValue
                }
                    .font(Theme.title(15))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ink)
            } else {
                Button {
                    unlock(character)
                } label: {
                    Text("shop.unlock \(character.price)")
                        .font(Theme.title(15))
                }
                .buttonStyle(.bordered)
                .tint(Theme.ink)
                .disabled(wallet < character.price)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Theme.marquee : Theme.ink, lineWidth: isSelected ? 4 : 2))
    }

    private func unlock(_ character: GameCharacter) {
        guard wallet >= character.price, !unlocked.contains(character) else { return }
        wallet -= character.price
        var updated = unlocked
        updated.insert(character)
        unlockedStorage = GameCharacter.store(updated)
        selected = character.rawValue
        SoundEngine.shared.play(.unlock)
    }
}
