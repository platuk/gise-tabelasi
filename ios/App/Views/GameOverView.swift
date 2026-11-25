import SwiftUI

/// Eski filmlerin kapanış kartı gibi: "SON".
struct GameOverView: View {
    let result: GameResult
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("gameover.title")
                .font(Theme.title(52))
            Text("gameover.floor \(result.floor)")
                .font(Theme.title(20))
            Text("gameover.score \(result.score)")
                .font(Theme.title(20))
            if result.isNewBest {
                Text("gameover.newBest")
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.marquee)
            }
            if result.checkpointFloor > 0 {
                Text("gameover.checkpoint \(result.checkpointFloor)")
                    .font(Theme.title(15))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                Button(action: onRetry) {
                    Text("gameover.retry")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.cream)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.ink))
                }
                Button(action: onMenu) {
                    Text("gameover.menu")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(Theme.ink)
        .padding(34)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink, lineWidth: 5))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.ink, lineWidth: 1.5).padding(9))
        .padding(28)
    }
}
