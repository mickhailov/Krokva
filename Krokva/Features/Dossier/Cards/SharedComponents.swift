import SwiftUI

struct DossierCard<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.krokvaGold)
                        .frame(width: 28, height: 28)
                        .background(Color.krokvaGold.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text(title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(Color.krokvaInk)
                Spacer(minLength: 0)
            }
            content
        }
        .padding(18)
        .background(Color.krokvaSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLine, lineWidth: 1)
        )
    }
}

struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.krokvaInk)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.krokvaInk3)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.krokvaSurfaceAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.krokvaLineSoft, lineWidth: 1)
        )
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .foregroundStyle(Color.krokvaInk3)
            Spacer(minLength: 16)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(Color.krokvaInk)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyCardState: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(Color.krokvaInk3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.krokvaInk2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
