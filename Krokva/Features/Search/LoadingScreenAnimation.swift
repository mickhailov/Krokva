import SwiftUI
import MapKit

// MARK: - LoadingScreenAnimation
//
// Fullscreen overlay while a report fetches.
// Layout:
//   • Brand header + live dot
//   • Address chip (typewriter on appear)
//   • Map hero — slowly zooms in; current-stage icon floats center
//   • Sliding step window — old rows exit upward, new ones enter from below
//   • Subtle progress bar

struct LoadingScreenAnimation: View {
    let addressText: String
    var cityName: String = "Winnipeg, MB"
    var stage: ReportLoadingStage = .normalizing
    var onCancel: (() -> Void)? = nil

    @State private var addressTyped = 0
    @State private var liveDot = false
    @State private var iconScale: CGFloat = 0.8
    @State private var displayProgress: Double = 0   // smoothly eased 0...1
    @State private var targetProgress: Double = 0
    @State private var progressTimer: Timer?
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    private let fallbackCoord = CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)

    private var idx: Int { stage.rawValue }
    private var active: LoadingDataStage { stage.data }

    // Sliding window: one completed behind + current + two upcoming
    private var visibleIndices: [Int] {
        let start = max(0, idx - 1)
        let end = min(loadingStages.count, start + 4)
        return Array(start..<end)
    }

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        addressChip
                            .padding(.top, 4)
                        mapHero
                        stepTimeline
                        progressBar
                        Spacer(minLength: 0)
                            .frame(height: 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                if onCancel != nil {
                    cancelButton
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color.cleanBg)
                }
            }
        }
        .onAppear { startAnimations() }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
        .onChange(of: stage) { _, newStage in
            targetProgress = Double(newStage.rawValue + 1) / Double(loadingStages.count)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                iconScale = 0.7
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(0.08)) {
                iconScale = 1.0
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            BrandMarkView(color: .cleanLabel, lineWidth: 2.2)
                .frame(width: 24, height: 24)

            Text("Krokva")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.cleanLabel)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.cleanSky)
                    .frame(width: 6, height: 6)
                    .scaleEffect(liveDot ? 1.0 : 0.55)
                    .opacity(liveDot ? 1.0 : 0.35)
                Text("LOADING")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color.cleanBg)
    }

    // MARK: Address chip

    private var addressChip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.cleanGreen)
                .frame(width: 8, height: 8)
            Text(String(addressText.prefix(addressTyped)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(1)
                .animation(nil, value: addressTyped)
            if addressTyped < addressText.count {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.cleanSky)
                    .frame(width: 2, height: 15)
                    .opacity(liveDot ? 1 : 0.2)
            }
            Spacer(minLength: 0)
            Text(cityName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cleanLabel3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
    }

    // MARK: Map hero

    private var mapHero: some View {
        ZStack {
            Map(position: $mapPosition)
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .mapControls {}
                .disabled(true)
                .allowsHitTesting(false)

            // Stage icon — frosted ring + solid disk
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 68, height: 68)
                Circle()
                    .fill(Color.cleanSky)
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.cleanSky.opacity(0.42), radius: 16, x: 0, y: 4)
                Image(systemName: active.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(iconScale)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
    }

    // MARK: Step timeline — sliding window

    private var stepTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleIndices.enumerated()), id: \.element) { pos, i in
                stepRow(index: i)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                if pos < visibleIndices.count - 1 {
                    Divider()
                        .padding(.leading, 62)
                        .foregroundStyle(Color.cleanSep)
                        .transition(.opacity)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: idx)
        .background(Color.cleanCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func stepRow(index: Int) -> some View {
        let isComplete = index < idx
        let isCurrent = index == idx
        let stage = loadingStages[index]

        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(isComplete ? Color.cleanSky : isCurrent ? Color.cleanSky.opacity(0.12) : Color.cleanBg)
                    .frame(width: 32, height: 32)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: stage.systemImage)
                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? Color.cleanSky : Color.cleanLabel3)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isComplete)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : isComplete ? .medium : .regular))
                    .foregroundStyle(isCurrent ? Color.cleanLabel : isComplete ? Color.cleanLabel : Color.cleanLabel3)
                    .lineLimit(1)
                if isCurrent {
                    Text(stage.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrent)

            Spacer(minLength: 0)

            // Status badge
            if isComplete {
                Text("Done")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cleanGreen)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else if isCurrent {
                LoadingDots()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCurrent ? 14 : 11)
        .background(isCurrent ? Color.cleanSkyWash : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }

    // MARK: Progress bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.cleanTrack)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cleanSky, .cleanIndigo],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(displayProgress))
                        .animation(.linear(duration: 0.02), value: displayProgress)
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(idx + 1) of \(loadingStages.count) checks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cleanLabel3)
                Spacer()
                Text("\(Int((displayProgress * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanSky)
            }
        }
    }

    // MARK: Cancel button

    private var cancelButton: some View {
        Button {
            onCancel?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.cleanLabel2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cleanCard, in: Capsule())
            .overlay(Capsule().stroke(Color.cleanSep, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Animations

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            liveDot = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            iconScale = 1.0
        }

        // Typewriter
        let count = addressText.count
        guard count > 0 else { addressTyped = count; return }
        let delay = min(0.04, 0.9 / Double(count))
        for i in 1...count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * delay) {
                addressTyped = i
            }
        }

        // Smoothly ease the progress bar / percentage toward the current stage
        // target so it glides between values instead of jumping in 10% steps.
        targetProgress = Double(idx + 1) / Double(loadingStages.count)
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let diff = targetProgress - displayProgress
            if diff > 0.0001 {
                // Asymptotic ease-out with a small floor so the number keeps
                // ticking even as it approaches the target; never overshoot it.
                let step = max(0.0007, diff * 0.05)
                displayProgress = min(targetProgress, displayProgress + step)
            } else if diff < 0 {
                displayProgress = targetProgress
            }
        }

        // Geocode address then start map zoom animation at the real location
        geocodeAndAnimate()
    }

    private func geocodeAndAnimate() {
        CLGeocoder().geocodeAddressString("\(addressText), \(cityName)") { placemarks, _ in
            let coord = placemarks?.first?.location?.coordinate ?? fallbackCoord
            DispatchQueue.main.async {
                mapPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                ))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                        mapPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
                        ))
                    }
                }
            }
        }
    }
}

// MARK: - Animated loading dots

private struct LoadingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.cleanSky)
                    .frame(width: 4, height: 4)
                    .scaleEffect(phase == i ? 1.4 : 0.8)
                    .opacity(phase == i ? 1.0 : 0.4)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Data model (unchanged)

struct LoadingDataStage: Identifiable {
    let id: String
    let title: String
    let detail: String
    let dataset: String
    let systemImage: String
}

enum ReportLoadingStage: Int, CaseIterable, Identifiable {
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
    var data: LoadingDataStage { loadingStages[rawValue] }
}

let loadingStages: [LoadingDataStage] = [
    LoadingDataStage(
        id: "normalize",
        title: "Parsing address",
        detail: "Normalizing civic number and street so city records can be matched reliably.",
        dataset: "Address index",
        systemImage: "number"
    ),
    LoadingDataStage(
        id: "assessment",
        title: "Property assessment",
        detail: "Roll number, assessed value, property tax, lot size, living area, year built.",
        dataset: "Assessment records",
        systemImage: "house.and.flag"
    ),
    LoadingDataStage(
        id: "nearby",
        title: "Nearby record keys",
        detail: "Matching the street core to link permits and orders to the right area.",
        dataset: "Nearby street records",
        systemImage: "point.3.connected.trianglepath.dotted"
    ),
    LoadingDataStage(
        id: "permits",
        title: "Building permit history",
        detail: "Detailed permits, trade permits, and nearby structural activity.",
        dataset: "Permit datasets",
        systemImage: "hammer"
    ),
    LoadingDataStage(
        id: "emergency",
        title: "Emergency response",
        detail: "Anonymized response records aggregated by year and neighbourhood.",
        dataset: "WFPS call logs",
        systemImage: "cross.case"
    ),
    LoadingDataStage(
        id: "health",
        title: "Public-health context",
        detail: "Neighbourhood totals vs citywide averages, age-group breakdown.",
        dataset: "Public-health records",
        systemImage: "list.clipboard"
    ),
    LoadingDataStage(
        id: "infrastructure",
        title: "Street & infrastructure",
        detail: "Speed limits, pothole repairs, trees, and vacant orders.",
        dataset: "Infrastructure data",
        systemImage: "road.lanes"
    ),
    LoadingDataStage(
        id: "map",
        title: "Map coordinates",
        detail: "Resolving coordinates for the subject property and nearby records.",
        dataset: "Map coordinates",
        systemImage: "map"
    ),
    LoadingDataStage(
        id: "comparables",
        title: "Assessment comparables",
        detail: "Nearby assessed properties for same-area context.",
        dataset: "Comparable properties",
        systemImage: "chart.bar.xaxis"
    ),
    LoadingDataStage(
        id: "assembling",
        title: "Assembling report",
        detail: "Combining finished records into cards, charts, and map layers.",
        dataset: "Final report",
        systemImage: "doc.text.magnifyingglass"
    ),
]

#Preview {
    LoadingScreenAnimation(
        addressText: "412 Wellington Crescent",
        cityName: "Winnipeg, MB",
        stage: .permits
    )
}
