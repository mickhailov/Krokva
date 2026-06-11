import SwiftUI

struct PropertyFinancialCard: View {
    let property: PropertyAssessment?

    @State private var isExpanded = false
    @State private var listingText = ""
    @State private var downPct: Int = 20
    @State private var annualRateValue: Double = 5.50
    @State private var amortYears = 25
    @FocusState private var focusListing: Bool

    // MARK: - Computed

    private var listingPrice: Double? {
        let raw = listingText.filter { $0.isNumber || $0 == "." }
        return Double(raw).flatMap { $0 > 0 ? $0 : nil }
    }

    private var purchasePrice: Double { listingPrice ?? property?.totalAssessedValue ?? 0 }
    private var downAmt: Double { purchasePrice * Double(downPct) / 100 }
    private var loanBase: Double { max(0, purchasePrice - downAmt) }

    private var cmhcPct: Double {
        guard downPct < 20 else { return 0 }
        if downPct >= 15 { return 2.80 }
        if downPct >= 10 { return 3.10 }
        return 4.00
    }

    private var cmhcAmt: Double { loanBase * cmhcPct / 100 }
    private var totalLoan: Double { loanBase + cmhcAmt }

    private var annualRate: Double { annualRateValue }
    private var monthlyRate: Double { annualRate / 100 / 12 }
    private var periods: Int { amortYears * 12 }

    private var monthlyPI: Double {
        guard totalLoan > 0, monthlyRate > 0 else { return 0 }
        let r = monthlyRate
        let N = Double(periods)
        return totalLoan * (r * pow(1 + r, N)) / (pow(1 + r, N) - 1)
    }

    private var monthlyTax: Double { (property?.propertyTax ?? 0) / 12 }
    private var totalMonthly: Double { monthlyPI + monthlyTax }

    private var storageKey: String {
        "listingPrice_" + (property?.rollNumber ?? property?.fullAddress ?? "unknown")
    }

    private var assessedVsListingDelta: Double? {
        guard let assessed = property?.totalAssessedValue, assessed > 0,
              let listing = listingPrice else { return nil }
        return (listing - assessed) / assessed * 100
    }

    // MARK: - Body

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                        priceSection
                        Divider()
                        taxSection
                        Divider()
                        calculatorSection
                        Divider()
                        monthlySection
                    }
                    .padding(18)
                }
            }
        }
        .onAppear {
            let saved = UserDefaults.standard.string(forKey: storageKey) ?? ""
            if listingText.isEmpty { listingText = saved }
        }
        .onChange(of: listingText) { _, new in
            UserDefaults.standard.set(new, forKey: storageKey)
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ownership costs")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(totalMonthly > 0 ? moFmt(totalMonthly) + " est." : "Tap to configure")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(totalMonthly > 0 ? Color.cleanSky : Color.cleanLabel3)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Price section

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionEyebrow("PRICE")
            assessedValueRow
            listingRow
        }
    }

    private var assessedValueRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Assessed value")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.cleanLabel2)
                if let year = property?.assessmentYear {
                    Text("\(year) data")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(money(property?.totalAssessedValue))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel)
                if let delta = assessedVsListingDelta {
                    deltaBadge(delta)
                }
            }
        }
    }

    private func deltaBadge(_ pct: Double) -> some View {
        let isAbove = pct > 0
        return Text(String(format: "%+.1f%% vs assessed", pct))
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundStyle(isAbove ? Color.cleanAmber : Color.cleanGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                isAbove ? Color.cleanAmberWash : Color.cleanGreenWash,
                in: Capsule()
            )
    }

    private var listingRow: some View {
        HStack {
            Text("Listing price")
                .font(.system(size: 14))
                .foregroundStyle(Color.cleanLabel2)
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                Text("$")
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(listingPrice != nil ? Color.cleanLabel : Color.cleanLabel3)
                TextField(plainDecimal(property?.totalAssessedValue.map { $0 * 1.3 }) ?? "Optional", text: $listingText)
                    .keyboardType(.numberPad)
                    .focused($focusListing)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: listingPrice != nil ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(listingPrice != nil ? Color.cleanLabel : Color.cleanLabel3)
                    .frame(minWidth: 80, maxWidth: 120)
            }
        }
    }

    // MARK: - Tax section

    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionEyebrow("PROPERTY TAX")
            finRow(
                "Annual" + (property?.propertyTaxIsEstimated == true ? " (est.)" : ""),
                value: money(property?.propertyTax),
                note: property?.propertyTaxYear.map { "\($0) rates" }
            )
            finRow("Monthly", value: monthlyTax > 0 ? moFmt(monthlyTax) : "—")
        }
    }

    // MARK: - Calculator section

    private var calculatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionEyebrow("PAYMENT CALCULATOR")

            finRow("Purchase price", value: purchasePrice > 0 ? money(purchasePrice) : "—")

            stepperRow(
                "Down payment",
                display: "\(downPct)%",
                canDecrement: downPct > 0,
                canIncrement: downPct < 50,
                onDecrement: { downPct = max(0, downPct - 5) },
                onIncrement: { downPct = min(50, downPct + 5) }
            )

            stepperRow(
                "Interest rate",
                display: String(format: "%.2f%%", annualRateValue),
                canDecrement: annualRateValue > 0.1,
                canIncrement: annualRateValue < 15.0,
                onDecrement: { annualRateValue = max(0.1, (annualRateValue * 100 - 10).rounded() / 100) },
                onIncrement: { annualRateValue = min(15.0, (annualRateValue * 100 + 10).rounded() / 100) }
            )

            stepperRow(
                "Amortization",
                display: "\(amortYears) yrs",
                canDecrement: amortYears > 5,
                canIncrement: amortYears < 30,
                onDecrement: { amortYears = max(5, amortYears - 5) },
                onIncrement: { amortYears = min(30, amortYears + 5) }
            )

            if cmhcPct > 0 {
                cmhcBanner
            }
        }
    }

    private func stepperRow(
        _ label: String,
        display: String,
        canDecrement: Bool,
        canIncrement: Bool,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.cleanLabel2)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { onDecrement() }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(canDecrement ? Color.cleanLabel2 : Color.cleanLabel3)
                }
                .buttonStyle(.plain)
                .disabled(!canDecrement)

                Rectangle().fill(Color.cleanSep).frame(width: 0.5, height: 18)

                Text(display)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel)
                    .frame(minWidth: 64)
                    .multilineTextAlignment(.center)

                Rectangle().fill(Color.cleanSep).frame(width: 0.5, height: 18)

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { onIncrement() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(canIncrement ? Color.cleanLabel2 : Color.cleanLabel3)
                }
                .buttonStyle(.plain)
                .disabled(!canIncrement)
            }
            .background(Color.cleanBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cleanSep, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Monthly section

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionEyebrow("MONTHLY ESTIMATE")

            finRow("Principal & interest",
                   value: monthlyPI > 0 ? moFmt(monthlyPI) : "—",
                   dim: monthlyPI == 0)

            if cmhcPct > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                    Text("Incl. CMHC \(String(format: "%.2f", cmhcPct))% — \(money(cmhcAmt)) added to loan")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel3)
                    Spacer()
                }
            }

            finRow("Property tax",
                   value: monthlyTax > 0 ? moFmt(monthlyTax) : "—",
                   dim: monthlyTax == 0)

            Divider()

            HStack {
                Text("Total monthly")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer()
                Text(totalMonthly > 0 ? moFmt(totalMonthly) : "—")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(totalMonthly > 0 ? Color.cleanSky : Color.cleanLabel3)
            }
            .padding(.top, 2)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .padding(.top, 1)
                Text("Utilities such as electricity, water, and other running costs are not included.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(10)
            .background(Color.cleanBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - CMHC banner

    private var cmhcBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanAmber)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("CMHC mortgage insurance required")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cleanAmber)
                Text("Down payment < 20% requires CMHC insurance. Rate: \(String(format: "%.2f", cmhcPct))% of the loan (\(money(cmhcAmt)) added to mortgage).")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.cleanAmberWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Helpers

    private func sectionEyebrow(_ text: String) -> some View {
        Text(text).eyebrow(color: .cleanLabel3)
    }

    private func finRow(
        _ label: String,
        value: String,
        note: String? = nil,
        dim: Bool = false
    ) -> some View {
        HStack(alignment: note != nil ? .top : .center) {
            if let note {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cleanLabel2)
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                }
            } else {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.cleanLabel2)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(dim ? Color.cleanLabel3 : Color.cleanLabel)
        }
    }

    private func moFmt(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: value)) ?? "$\(Int(value))") + "/mo"
    }

    private func plainDecimal(_ value: Double?) -> String? {
        guard let value else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value))
    }
}
