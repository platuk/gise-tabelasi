import GameCore
import SwiftUI

struct LevelView: View {
    @EnvironmentObject private var model: AppModel
    let level: Level
    @Binding var path: [Int]

    @State private var game: GameState?
    @State private var message: String
    @State private var successCount = 0

    init(level: Level, path: Binding<[Int]>) {
        self.level = level
        self._path = path
        let game = try? GameState(level: level)
        self._game = State(initialValue: game)
        self._message = State(initialValue: game == nil ? "" : String(localized: "game.hint.start"))
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let game {
                VStack(spacing: 24) {
                    MarqueeView(level: level, found: game.foundWords)

                    HStack(spacing: 8) {
                        ForEach(level.reels.indices, id: \.self) { index in
                            ReelView(
                                letter: game.letter(atReel: index),
                                canRotate: game.canRotate(reel: index),
                                position: index + 1
                            ) { step in
                                rotate(reel: index, by: step)
                            }
                        }
                    }

                    Text(message)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: 24)
                        .accessibilityAddTraits(.updatesFrequently)

                    Button {
                        undo()
                    } label: {
                        Label("game.undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!game.canUndo)

                    Spacer()
                }
                .padding()

                if game.isComplete {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    CompletionView(
                        hasNext: model.pack?.nextLevel(after: level.id) != nil,
                        onNext: goToNextLevel,
                        onBack: { path = [] }
                    )
                }
            } else {
                Text("error.invalidLevel")
                    .foregroundStyle(Theme.ink)
                    .padding()
            }
        }
        .animation(.easeOut(duration: 0.25), value: game?.isComplete)
        .navigationTitle(Text("level.title \(level.id)"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: successCount)
        .onAppear {
            if game?.isComplete == true { model.markCompleted(level) }
        }
    }

    private func rotate(reel: Int, by step: Int) {
        guard var current = game else { return }
        let result = current.rotate(reel: reel, by: step)
        game = current
        switch result {
        case .newWord(let word):
            message = String(localized: "game.newWord \(word)")
            successCount += 1
        case .alreadyFound(let word):
            message = String(localized: "game.alreadyFound \(word)")
        case .notATarget:
            message = ""
        case .ignored:
            break
        }
        if current.isComplete {
            model.markCompleted(level)
        }
    }

    private func undo() {
        guard var current = game, current.undo() else { return }
        game = current
        message = ""
    }

    private func goToNextLevel() {
        guard let next = model.pack?.nextLevel(after: level.id) else {
            path = []
            return
        }
        path = [next.id]
    }
}

struct MarqueeView: View {
    let level: Level
    let found: [String]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(level.targets, id: \.self) { target in
                let isFound = found.contains(target)
                HStack(spacing: 12) {
                    Circle()
                        .fill(isFound ? Theme.bulbOn : Theme.bulbOff)
                        .frame(width: 18, height: 18)
                        .shadow(color: isFound ? Theme.bulbOn : .clear, radius: 8)
                    Text(verbatim: isFound ? target : placeholder)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.paper)
                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isFound ? Text(verbatim: target) : Text("marquee.hidden"))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.marquee))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink, lineWidth: 4))
    }

    private var placeholder: String {
        Array(repeating: "_", count: level.wordLength).joined(separator: " ")
    }
}

struct ReelView: View {
    let letter: String
    let canRotate: Bool
    let position: Int
    let onRotate: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button {
                onRotate(-1)
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 44, height: 32)
            }
            .accessibilityLabel(Text("reel.up \(position)"))

            Text(verbatim: letter)
                .font(Theme.title(40))
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 60)
                .frame(height: 72)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 3))
                .gesture(
                    DragGesture(minimumDistance: 20).onEnded { value in
                        guard canRotate else { return }
                        onRotate(value.translation.height < 0 ? 1 : -1)
                    }
                )
                .accessibilityHidden(true)

            Button {
                onRotate(1)
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 44, height: 32)
            }
            .accessibilityLabel(Text("reel.down \(position)"))
        }
        .disabled(!canRotate)
        .opacity(canRotate ? 1 : 0.6)
    }
}

struct CompletionView: View {
    let hasNext: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("game.complete.title")
                .font(Theme.title(32))
                .foregroundStyle(Theme.ink)
            if hasNext {
                Button("game.complete.next", action: onNext)
                    .buttonStyle(.borderedProminent)
            } else {
                Text("game.allDone")
                    .foregroundStyle(Theme.ink)
            }
            Button("game.complete.back", action: onBack)
                .buttonStyle(.bordered)
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink, lineWidth: 4))
        .padding()
        .transition(.scale.combined(with: .opacity))
    }
}
