import GameCore
import SwiftUI

struct LevelListView: View {
    @EnvironmentObject private var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let pack = model.pack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(pack.levels) { level in
                            let unlocked = model.isUnlocked(level)
                            NavigationLink(value: level.id) {
                                LevelTile(
                                    number: level.id,
                                    unlocked: unlocked,
                                    completed: model.progress.isCompleted(level.id)
                                )
                            }
                            .disabled(!unlocked)
                        }
                    }
                    .padding()
                }
            } else {
                Text(model.loadError ?? "")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .padding()
            }
        }
    }
}

struct LevelTile: View {
    let number: Int
    let unlocked: Bool
    let completed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(unlocked ? Theme.marquee : Theme.bulbOff)
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.ink, lineWidth: 3)
            if unlocked {
                Text(verbatim: "\(number)")
                    .font(Theme.title(28))
                    .foregroundStyle(Theme.paper)
            } else {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.paper)
            }
        }
        .frame(height: 72)
        .overlay(alignment: .topTrailing) {
            if completed {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.bulbOn)
                    .padding(6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("level.title \(number)"))
        .accessibilityValue(accessibilityState)
    }

    private var accessibilityState: Text {
        if completed { return Text("level.completed") }
        if !unlocked { return Text("level.locked") }
        return Text(verbatim: "")
    }
}
