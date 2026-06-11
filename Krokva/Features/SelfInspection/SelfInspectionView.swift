import SwiftUI

struct SelfInspectionView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()

                VStack(spacing: 14) {
                    Image(systemName: "checklist")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.cleanLabel3)

                    Text("Self Inspection")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.cleanLabel)

                    Text("Coming soon — walk through your property room by room and log conditions, defects, and notes.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cleanLabel3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .cleanNavBar(title: "Self Inspection")
        }
    }
}
