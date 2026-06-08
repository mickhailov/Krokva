import SwiftUI

// MARK: - LoadingScreenAnimation (Civic Modernist)
//
// Blueprint-inspired loading screen shown while a dossier is being fetched.
// It communicates the real shape of the fetch: normalize address, locate the
// property record, then assemble assessment, permit, emergency, health,
// infrastructure, map, and comparable datasets.

struct LoadingScreenAnimation: View {
    let addressText: String
    var cityName: String = "Winnipeg, MB"
    var stage: DossierLoadingStage = .normalizing

    @State private var gridOpacity: CGFloat = 0
    @State private var cornerTicks: CGFloat = 0
    @State private var propertyBox: CGFloat = 0
    @State private var pinScale: CGFloat = 0
    @State private var pinOpacity: CGFloat = 0
    @State private var addressTyped: Int = 0
    @State private var statusPulse: CGFloat = 0.55
    @State private var scanOffset: CGFloat = -120

    private var activeStage: LoadingDataStage {
        stage.data
    }

    private var currentStageIndex: Int { stage.rawValue }

    var body: some View {
        ZStack {
            Color.krokvaPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 6)

                GeometryReader { geo in
                    ZStack {
                        blueprintGrid
                            .opacity(gridOpacity)

                        scanningLine(height: geo.size.height)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                Spacer(minLength: 28)

                                HStack(alignment: .center, spacing: 18) {
                                    propertyBlueprint
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Building municipal record")
                                            .eyebrow(color: Color.krokvaInk3)
                                        Text(String(addressText.prefix(addressTyped)))
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundStyle(Color.krokvaInk)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(minHeight: 48, alignment: .topLeading)
                                        cityChip
                                    }
                                }

                                currentWorkPanel

                                datasetPanel

                                Text("Open data can respond at different speeds. The app keeps checking each source until the dossier is ready.")
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.krokvaInk3)
                                    .multilineTextAlignment(.leading)
                                    .opacity(statusPulse)
                                    .padding(.top, 2)

                                Spacer(minLength: 28)
                            }
                            .padding(.horizontal, 20)
                            .frame(minHeight: geo.size.height)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .onAppear { playAnimation() }
    }

    private var headerBar: some View {
        HStack {
            BrandMarkView(color: .krokvaNavy, lineWidth: 2.3)
                .frame(width: 20, height: 20)

            Text("Krokva")
                .font(KrokvaTypography.wordmark)
                .foregroundStyle(Color.krokvaNavy)

            Spacer()

            Text("Loading")
                .font(KrokvaTypography.monoSmall)
                .tracking(2.2)
                .foregroundStyle(Color.krokvaInk3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 13)
        .padding(.bottom, 13)
        .background(Color.krokvaSurface.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.krokvaLineSoft).frame(height: 1)
        }
    }

    private var blueprintGrid: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 40
            for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.krokvaInk.opacity(0.07)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }

    private func scanningLine(height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.krokvaGold.opacity(0.00),
                        Color.krokvaGold.opacity(0.32),
                        Color.krokvaGold.opacity(0.00)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 120, height: height)
            .blur(radius: 10)
            .offset(x: scanOffset)
            .allowsHitTesting(false)
    }

    private var propertyBlueprint: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.krokvaNavy, lineWidth: 1.5)
                .frame(width: 118, height: 92)
                .opacity(propertyBox)

            cornerTickMark(at: .topLeading).opacity(cornerTicks)
            cornerTickMark(at: .topTrailing).opacity(cornerTicks)
            cornerTickMark(at: .bottomLeading).opacity(cornerTicks)
            cornerTickMark(at: .bottomTrailing).opacity(cornerTicks)

            ZStack {
                Circle()
                    .fill(Color.krokvaGold.opacity(0.10))
                    .frame(width: 58, height: 58)
                    .scaleEffect(pinScale * 0.55)
                Circle()
                    .stroke(Color.krokvaGold.opacity(0.42), lineWidth: 1)
                    .frame(width: 42, height: 42)
                    .scaleEffect(pinScale)
                Circle()
                    .fill(Color.krokvaGold)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.krokvaPaper)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(pinOpacity)
        }
        .frame(width: 118, height: 92)
    }

    private var cityChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.krokvaGreen)
                .frame(width: 7, height: 7)
            Text(cityName)
            Text("LIVE")
                .foregroundStyle(Color.krokvaGreen)
        }
        .font(KrokvaTypography.monoSmall)
        .tracking(0.8)
        .foregroundStyle(Color.krokvaInk2)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.krokvaSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.krokvaLineSoft, lineWidth: 1))
    }

    private var currentWorkPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.krokvaGold.opacity(0.12))
                    Image(systemName: activeStage.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.krokvaGold)
                        .symbolEffect(.pulse, value: stage)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Now checking")
                        .eyebrow(color: Color.krokvaInk3)
                    Text(activeStage.title)
                        .font(KrokvaTypography.body.weight(.semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Text(activeStage.detail)
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: Double(currentStageIndex + 1), total: Double(loadingStages.count))
                .tint(Color.krokvaGold)
                .animation(.easeInOut(duration: 0.35), value: stage)
        }
        .padding(16)
        .background(Color.krokvaSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLineSoft, lineWidth: 1)
        )
    }

    private var datasetPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Data being assembled")
                    .eyebrow(color: Color.krokvaInk3)
                Spacer()
                Text("\(currentStageIndex + 1)/\(loadingStages.count)")
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.krokvaInk3)
            }

            VStack(spacing: 9) {
                ForEach(loadingStages.indices, id: \.self) { index in
                    LoadingStageRow(
                        stage: loadingStages[index],
                        state: rowState(for: index),
                        isCurrent: index == currentStageIndex
                    )
                }
            }
        }
        .padding(16)
        .background(Color.krokvaSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLineSoft, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cornerTickMark(at alignment: Alignment) -> some View {
        ZStack {
            Rectangle().frame(width: 12, height: 1.2)
            Rectangle().frame(width: 1.2, height: 12)
        }
        .frame(width: 12, height: 12, alignment: alignment)
        .foregroundStyle(Color.krokvaGold.opacity(0.8))
        .frame(maxWidth: 118, maxHeight: 92, alignment: alignment)
        .padding(7)
    }

    private func rowState(for index: Int) -> LoadingStageState {
        if index == currentStageIndex { return .current }
        if index < currentStageIndex { return .complete }
        return .pending
    }

    private func playAnimation() {
        withAnimation(.easeOut(duration: 0.4)) { gridOpacity = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.55)) { propertyBox = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.35)) { cornerTicks = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                pinOpacity = 1
                pinScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let charCount = addressText.count
            guard charCount > 0 else { addressTyped = 0; return }
            let delayPerChar = min(0.035, 0.9 / Double(max(charCount, 1)))
            for i in 1...charCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * delayPerChar) {
                    addressTyped = i
                }
            }
        }

        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            scanOffset = UIScreen.main.bounds.width + 140
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                statusPulse = 1.0
            }
        }
    }
}

struct LoadingDataStage: Identifiable {
    let id: String
    let title: String
    let detail: String
    let dataset: String
    let systemImage: String
}

enum DossierLoadingStage: Int, CaseIterable, Identifiable {
    case normalizing
    case assessment
    case nearbyRecords
    case permits
    case emergency
    case health
    case infrastructure
    case mapCoordinates
    case comparables
    case assembling

    var id: Int { rawValue }

    var data: LoadingDataStage {
        loadingStages[rawValue]
    }
}

private enum LoadingStageState {
    case complete
    case current
    case pending
}

private struct LoadingStageRow: View {
    let stage: LoadingDataStage
    let state: LoadingStageState
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            statusMark

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.dataset)
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(isCurrent ? Color.krokvaInk : Color.krokvaInk2)
                    .lineLimit(1)
                Text(stage.title)
                    .font(KrokvaTypography.monoSmall)
                    .tracking(0.6)
                    .foregroundStyle(Color.krokvaInk3)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusMark: some View {
        switch state {
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.krokvaGreen)
                .frame(width: 20)
        case .current:
            ZStack {
                Circle()
                    .fill(Color.krokvaGold.opacity(0.18))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(Color.krokvaGold)
                    .frame(width: 8, height: 8)
            }
            .scaleEffect(isCurrent ? 1.05 : 1.0)
        case .pending:
            Circle()
                .stroke(Color.krokvaLine, lineWidth: 1.2)
                .frame(width: 12, height: 12)
                .frame(width: 20)
        }
    }
}

let loadingStages: [LoadingDataStage] = [
    LoadingDataStage(
        id: "normalize",
        title: "Parsing civic number and street",
        detail: "Normalizing the address so city records can be queried reliably.",
        dataset: "Address index",
        systemImage: "number"
    ),
    LoadingDataStage(
        id: "assessment",
        title: "Finding the property assessment",
        detail: "Looking for roll number, assessed value, property tax, lot size, living area, and year built.",
        dataset: "Assessment records",
        systemImage: "house.and.flag"
    ),
    LoadingDataStage(
        id: "nearby",
        title: "Finding nearby record keys",
        detail: "Matching the street core so permits and orders can be linked to the right address area.",
        dataset: "Nearby street records",
        systemImage: "point.3.connected.trianglepath.dotted"
    ),
    LoadingDataStage(
        id: "permits",
        title: "Reading building permit history",
        detail: "Checking detailed permits, trade permits, and nearby structural activity.",
        dataset: "Permit datasets",
        systemImage: "hammer"
    ),
    LoadingDataStage(
        id: "emergency",
        title: "Counting emergency response activity",
        detail: "Aggregating anonymized response records by year and neighbourhood.",
        dataset: "WFPS call logs",
        systemImage: "cross.case"
    ),
    LoadingDataStage(
        id: "health",
        title: "Building public-health context",
        detail: "Comparing neighbourhood totals with citywide averages and age-group context.",
        dataset: "Public-health records",
        systemImage: "list.clipboard"
    ),
    LoadingDataStage(
        id: "infrastructure",
        title: "Checking street and infrastructure signals",
        detail: "Looking at speed limits, pothole repairs, trees, and active vacant orders.",
        dataset: "Infrastructure data",
        systemImage: "road.lanes"
    ),
    LoadingDataStage(
        id: "map",
        title: "Placing nearby records on the map",
        detail: "Resolving coordinates for the subject property and nearby records.",
        dataset: "Map coordinates",
        systemImage: "map"
    ),
    LoadingDataStage(
        id: "comparables",
        title: "Finding assessment comparables",
        detail: "Collecting nearby assessed properties for same-area context.",
        dataset: "Comparable properties",
        systemImage: "chart.bar.xaxis"
    ),
    LoadingDataStage(
        id: "assembling",
        title: "Assembling the dossier",
        detail: "Combining the finished records into the cards, charts, and map layers.",
        dataset: "Final dossier",
        systemImage: "doc.text.magnifyingglass"
    )
]

#Preview {
    LoadingScreenAnimation(addressText: "412 Wellington Crescent", cityName: "Winnipeg, MB")
}
