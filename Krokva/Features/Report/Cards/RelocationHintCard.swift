import SwiftUI

/// Report-screen nudge for the "moving" scenario: invites the user to compare
/// this address against their current/home address. When a current address is
/// set, it also shows the top ways this place is better or worse.
struct RelocationHintCard: View {
    /// The user's current/home address, or nil if none is marked yet.
    let currentAddress: String?
    /// This report scored against the current address (nil when no current set).
    let score: RelocationScore?
    let onOpenCompare: () -> Void

    var body: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.cleanSky)
                    Text("THINKING OF MOVING?").eyebrow(color: .cleanLabel3)
                }

                if let currentAddress {
                    Text("Compare with your current address")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    Text("Current: \(shortAddress(currentAddress))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                    if let score { deltas(score) }
                } else {
                    Text("Set a current address to compare a move here")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    Text("In Compare, mark the address you live at, then this report is scored against it.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cleanLabel2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onOpenCompare) {
                    HStack(spacing: 6) {
                        Text("Open comparison")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.cleanSky, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func deltas(_ score: RelocationScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !score.betterReasons.isEmpty {
                deltaLine(icon: "arrow.up.circle.fill", tint: .cleanSky,
                          text: "Better here: " + score.betterReasons.joined(separator: ", "))
            }
            if !score.worseReasons.isEmpty {
                deltaLine(icon: "arrow.down.circle.fill", tint: .cleanAmber,
                          text: "Worse here: " + score.worseReasons.joined(separator: ", "))
            }
            if score.betterReasons.isEmpty && score.worseReasons.isEmpty {
                Text("Very similar to your current address on the data available.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
        .padding(.top, 2)
    }

    private func deltaLine(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
