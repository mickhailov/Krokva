import SwiftUI

struct PropertyFinancialCard: View {
    let property: PropertyAssessment?

    @State private var isExpanded = false

    @Environment(\.reportPDFRender) private var pdfRender
    @State private var listingText = ""
    @State private var isEditingListing = false
    @State private var downText = "20"
    @State private var rateText = "4.00"
    @State private var amortText = "25"
    @FocusState private var focusedField: Field?

    private enum Field { case listing, down, rate, amort }

    // MARK: - Computed

    private var listingPrice: Double? {
        let raw = listingText.filter { $0.isNumber || $0 == "." }
        return Double(raw).flatMap { $0 > 0 ? $0 : nil }
    }

    // Editable calculator inputs are parsed (and clamped to sane bounds) from their text fields.
    private var downPct: Double {
        min(max(Double(downText.filter { $0.isNumber || $0 == "." }) ?? 0, 0), 100)
    }
    private var annualRateValue: Double {
        min(max(Double(rateText.filter { $0.isNumber || $0 == "." }) ?? 0, 0), 25)
    }
    private var amortYears: Int {
        min(max(Int(amortText.filter { $0.isNumber }) ?? 25, 1), 40)
    }

    private var suggestedListingPrice: Double? {
        property?.totalAssessedValue.map { ($0 * 1.3).rounded() }
    }

    private var purchasePrice: Double {
        listingPrice ?? suggestedListingPrice ?? property?.totalAssessedValue ?? 0
    }
    private var downAmt: Double { purchasePrice * downPct / 100 }
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
                if isExpanded || pdfRender {
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
            if listingText.isEmpty {
                listingText = saved.isEmpty ? (plainDecimal(suggestedListingPrice) ?? "") : saved
            }
        }
        .onChange(of: listingText) { _, new in
            UserDefaults.standard.set(new, forKey: storageKey)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
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
            suggestedListingRow
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

    private var suggestedListingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Suggested listing price")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cleanLabel2)
                    Text("Used for all payment calculations")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                }
                Spacer(minLength: 8)
                if !isEditingListing {
                    Text(money(purchasePrice > 0 ? purchasePrice : nil))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel)
                }
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isEditingListing.toggle()
                    }
                    if isEditingListing { focusedField = .listing }
                } label: {
                    Image(systemName: isEditingListing ? "checkmark" : "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isEditingListing ? .white : Color.cleanSky)
                        .frame(width: 30, height: 30)
                        .background(isEditingListing ? Color.cleanSky : Color.cleanSky.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if isEditingListing {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel3)
                    TextField(plainDecimal(suggestedListingPrice) ?? "Listing price", text: $listingText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .listing)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cleanBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(focusedField == .listing ? Color.cleanSky : Color.cleanSep,
                                lineWidth: focusedField == .listing ? 1 : 0.5)
                )
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

            entryRow("Down payment", text: $downText, suffix: "%", field: .down, keyboard: .decimalPad)
            if downAmt > 0 {
                Text(money(downAmt) + " down payment")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            entryRow("Interest rate", text: $rateText, suffix: "%", field: .rate, keyboard: .decimalPad)
            entryRow("Amortization", text: $amortText, suffix: "yrs", field: .amort, keyboard: .numberPad)

            if cmhcPct > 0 {
                cmhcBanner
            }
        }
    }

    private func entryRow(
        _ label: String,
        text: Binding<String>,
        suffix: String,
        field: Field,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.cleanLabel2)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                TextField("", text: text)
                    .keyboardType(keyboard)
                    .focused($focusedField, equals: field)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel)
                    .frame(minWidth: 40, maxWidth: 64)
                Text(suffix)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.cleanLabel3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cleanBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(focusedField == field ? Color.cleanSky : Color.cleanSep,
                            lineWidth: focusedField == field ? 1 : 0.5)
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
