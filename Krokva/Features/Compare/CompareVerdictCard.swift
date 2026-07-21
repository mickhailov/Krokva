import SwiftUI

/// The "which address is the better move" summary shown above the comparison
/// table (and in the compare PDF). Scores every candidate against the current
/// address and explains the top reasons each is better or worse.
struct RelocationVerdictCard: View {
    let verdict: RelocationVerdict

    var body: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(verdict.scores) { score in
                    candidateRow(score)
                }
                Text("Weighted across price, safety, space, schools, transit and local area vs your current address. Guidance only, not advice.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MOVING VERDICT").eyebrow(color: .cleanLabel3)
            if let winner = verdict.winner {
                Text("\(shortAddress(winner.address)) looks like the strongest move")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("None of the candidates clearly beats \(shortAddress(verdict.currentAddress))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("vs current: \(shortAddress(verdict.currentAddress))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
        }
    }

    private func candidateRow(_ score: RelocationScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: score.isImprovement ? "arrow.up.circle.fill"
                        : score.isRegression ? "arrow.down.circle.fill" : "equal.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(score.isImprovement ? Color.cleanSky
                        : score.isRegression ? Color.cleanAmber : Color.cleanLabel3)
                Text(shortAddress(score.address))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer()
                Text(verdictTag(score))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(score.isImprovement ? Color.cleanSky
                        : score.isRegression ? Color.cleanAmber : Color.cleanLabel3)
            }
            if !score.betterReasons.isEmpty {
                reasonLine(icon: "plus", tint: .cleanSky, text: "Better: " + score.betterReasons.joined(separator: ", "))
            }
            if !score.worseReasons.isEmpty {
                reasonLine(icon: "minus", tint: .cleanAmber, text: "Worse: " + score.worseReasons.joined(separator: ", "))
            }
            if score.betterReasons.isEmpty && score.worseReasons.isEmpty {
                Text("Too close to call on the data available.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
        .padding(.vertical, 2)
    }

    private func reasonLine(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func verdictTag(_ score: RelocationScore) -> String {
        if score.isImprovement { return "Better move" }
        if score.isRegression { return "Step down" }
        return "About even"
    }
}

/// Cover block for the compare PDF: title, date, and the addresses in play.
struct CompareCoverView: View {
    let props: [SavedReport]
    let currentIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Krokva")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer()
                Text("ADDRESS COMPARISON")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.cleanLabel3)
            }
            Text("Comparing \(props.count) addresses")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.cleanLabel)
            Text("Generated \(Date.now.formatted(date: .long, time: .shortened))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(props.enumerated()), id: \.offset) { i, prop in
                    HStack(spacing: 8) {
                        Text(i == currentIndex ? "CURRENT" : "CANDIDATE")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(i == currentIndex ? Color.cleanSky : Color.cleanLabel3)
                            .frame(width: 66, alignment: .leading)
                        Text(prop.address)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.cleanLabel)
                    }
                }
            }
            .padding(.top, 2)
            Divider().foregroundStyle(Color.cleanSep)
        }
    }
}
