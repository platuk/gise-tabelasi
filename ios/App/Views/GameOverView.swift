import SwiftUI

/// Eski filmlerin kapanış kartı gibi: "SON". Sıralı boss modunda yenilen boss sayısını gösterir.
struct GameOverView: View {
    let result: GameResult
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("gameover.title")
                .font(Theme.title(52))
            if result.bossRush {
                Text("gameover.rush \(result.bossesBeaten)")
                    .font(Theme.title(20))
                    .multilineTextAlignment(.center)
                Text("gameover.score \(result.score)")
                    .font(Theme.title(18))
                Text("gameover.rushBest \(result.bestBossRush)")
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.marquee)
            } else {
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
            }
            HStack(spacing: 12) {
                TicketButton(title: "gameover.retry", size: 18, action: onRetry)
                TicketButton(title: "gameover.menu", size: 18, filled: false, action: onMenu)
            }
            .padding(.top, 8)
        }
        .foregroundStyle(Theme.ink)
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink, lineWidth: 5))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.ink, lineWidth: 1.5).padding(9))
        .padding(24)
    }
}
