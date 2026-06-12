//
//  SimpleStudioSections.swift
//  BuxMuse
//
//  Simple Studio hub sections — tiles, charts, lists.
//

import SwiftUI
import Charts

// MARK: - Hero + tiles

struct SimpleStudioHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let display: SimpleStudioHubDisplay

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.businessTitle)
                            .font(.system(size: 18, weight: .bold))
                            .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Local · Private · On your phone")
                            .font(.system(size: 11, weight: .medium))
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        BuxCatalogDynamicText(key: "Today kept")
                            .font(.system(size: 10, weight: .semibold))
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                        Text(display.todayKeptFormatted)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
            }
        }
    }
}

struct SimpleStudioMetricTiles: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let display: SimpleStudioHubDisplay

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: BuxTokens.tight), GridItem(.flexible(), spacing: BuxTokens.tight)],
            spacing: BuxTokens.tight
        ) {
            tile(title: "Made", value: display.madeFormatted, color: .green)
            tile(title: "Spent", value: display.spentFormatted, subtitle: display.spentFootnote, color: .orange)
            tile(title: "Waiting", value: display.waitingFormatted, color: .yellow)
            tile(title: "I owe", value: display.oweFormatted, color: .red)
        }
    }

    private func tile(title: String, value: String, subtitle: String? = nil, color: Color) -> some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogText.text(title)
                    .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - This month hero (hub)

struct SimpleStudioThisMonthCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let display: SimpleStudioHubDisplay
    var chartHeight: CGFloat = 200

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.periodTitle)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    if let range = display.periodRangeSubtitle {
                        Text(range)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    BuxCatalogDynamicText(key: "Tap to open My money")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }

                SimpleStudioDonutChart(
                    slices: display.monthChartSlices,
                    height: chartHeight,
                    isSelectable: false
                )

                if display.monthChartSlices.isEmpty {
                    BuxCatalogDynamicText(key: "Log work to see where your money goes.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    monthSummaryRow
                }
            }
        }
    }

    private var monthSummaryRow: some View {
        HStack(spacing: BuxTokens.tight) {
            summaryPill(label: "Made", value: display.madeFormatted, color: .green)
            summaryPill(label: "Spent", value: display.spentFormatted, color: .orange)
            summaryPill(label: "Waiting", value: display.waitingFormatted, color: .yellow)
            summaryPill(label: "I owe", value: display.oweFormatted, color: .red)
        }
    }

    private func summaryPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                BuxCatalogText.text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Charts

struct SimpleStudioDonutChart: View {
    let slices: [SimpleChartSlice]
    var height: CGFloat = 160
    var isSelectable: Bool = true
    @Binding var selectedSliceID: String?

    @State private var hasAppeared = false

    private static let innerRadiusRatio: CGFloat = 0.58
    static let selectionAnimation = Animation.easeInOut(duration: 0.22)

    init(
        slices: [SimpleChartSlice],
        height: CGFloat = 160,
        isSelectable: Bool = true,
        selectedSliceID: Binding<String?> = .constant(nil)
    ) {
        self.slices = slices
        self.height = height
        self.isSelectable = isSelectable
        _selectedSliceID = selectedSliceID
    }

    private var sectorValues: [(id: String, value: Double)] {
        slices.map { slice in
            (
                slice.id,
                hasAppeared ? NSDecimalNumber(decimal: slice.value).doubleValue : 0
            )
        }
    }

    @ViewBuilder
    var body: some View {
        if slices.isEmpty {
            RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .frame(height: height)
                .overlay(
                    BuxCatalogDynamicText(key: "Log work to see your month")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                )
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        Chart {
            ForEach(sectorValues, id: \.id) { item in
                SectorMark(
                    angle: .value("Amount", item.value),
                    innerRadius: .ratio(Self.innerRadiusRatio),
                    angularInset: 2
                )
                .foregroundStyle(baseSliceColor(id: item.id))
                .opacity(sliceOpacity(for: item.id))
            }
        }
        .chartLegend(.hidden)
        .frame(height: height)
        .chartOverlay { proxy in
            if isSelectable {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard let plotAnchor = proxy.plotFrame else { return }
                                    let plotFrame = geometry[plotAnchor]
                                    let location = CGPoint(
                                        x: value.location.x - plotFrame.origin.x,
                                        y: value.location.y - plotFrame.origin.y
                                    )
                                    handleTap(at: location, in: plotFrame.size)
                                }
                        )
                }
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.86)) {
                hasAppeared = true
            }
        }
    }

    private func sliceOpacity(for id: String) -> Double {
        guard let selectedSliceID else { return 1 }
        return selectedSliceID == id ? 1 : 0.32
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        guard let sliceID = sliceID(at: location, in: size) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(Self.selectionAnimation) {
            if selectedSliceID == sliceID {
                selectedSliceID = nil
            } else {
                selectedSliceID = sliceID
            }
        }
    }

    /// Maps a tap to a slice id. Swift Charts draws sectors from 12 o'clock clockwise.
    private func sliceID(at location: CGPoint, in size: CGSize) -> String? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)

        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * Self.innerRadiusRatio
        guard distance >= innerRadius, distance <= outerRadius else { return nil }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let total = sectorValues.reduce(0) { $0 + $1.value }
        guard total > 0 else { return nil }

        var start: Double = 0
        for item in sectorValues {
            let sweep = (item.value / total) * 2 * .pi
            if angle >= start, angle < start + sweep {
                return item.id
            }
            start += sweep
        }
        return sectorValues.last?.id
    }

    private func baseSliceColor(id: String) -> Color {
        switch id {
        case "made": return .green
        case "spent": return .orange
        case "waiting": return .yellow
        case "owe": return .red
        default: return BuxChartColors.color(forCategoryName: id, fallbackIndex: 0)
        }
    }
}

struct SimpleStudioChartLegend: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let slices: [SimpleChartSlice]
    var selectedSliceID: Binding<String?> = .constant(nil)
    var onSelectSlice: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            ForEach(slices) { slice in
                Button {
                    withAnimation(SimpleStudioDonutChart.selectionAnimation) {
                        if selectedSliceID.wrappedValue == slice.id {
                            selectedSliceID.wrappedValue = nil
                        } else {
                            selectedSliceID.wrappedValue = slice.id
                            onSelectSlice?(slice.id)
                        }
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(color(for: slice.id))
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.system(size: 12, weight: selectedSliceID.wrappedValue == slice.id ? .bold : .medium))
                            .foregroundColor(
                                selectedSliceID.wrappedValue == slice.id
                                    ? themeManager.labelPrimary(for: colorScheme)
                                    : themeManager.labelSecondary(for: colorScheme)
                            )
                        Spacer()
                        Text(slice.valueFormatted)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(for id: String) -> Color {
        switch id {
        case "made": return .green
        case "spent": return .orange
        case "waiting": return .yellow
        case "owe": return .red
        default: return .gray
        }
    }
}

// MARK: - Waiting on

struct SimpleStudioWaitingSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStore: SimpleStudioStore

    let items: [SimpleWaitingItem]
    var onMarkPaid: ((UUID) -> Void)?
    var onRemind: ((SimpleWaitingItem) -> Void)?
    var onTap: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Waiting on")

            if items.isEmpty {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                    BuxCatalogDynamicText(key: "Nobody owes you right now — nice.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                List {
                    ForEach(Array(items.prefix(5))) { item in
                        waitingRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if let onMarkPaid {
                                    Button(BuxCatalogLabel.string("Paid", locale: appSettingsManager.interfaceLocale)) {
                                        onMarkPaid(item.id)
                                    }
                                        .tint(.green)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.visible)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(min(items.count, 5)) * 64)
                .background(themeManager.cardFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                        .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                )
            }
        }
    }

    private func waitingRow(_ item: SimpleWaitingItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.customerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(
                    BuxLocalizedString.format(
                        "%@ · %lldd",
                        locale: appSettingsManager.interfaceLocale,
                        item.jobLabel,
                        item.daysWaiting
                    )
                )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                if let chip = quoteStatusChip(for: item) {
                    Text(chip)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(chipColor(chip).opacity(0.15))
                        .foregroundColor(chipColor(chip))
                        .clipShape(Capsule())
                }
                if let advance = item.advanceBalanceFormatted {
                    Text(
                        BuxLocalizedString.format(
                            "Advance left: %@",
                            locale: appSettingsManager.interfaceLocale,
                            advance
                        )
                    )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(item.amountFormatted)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                HStack(spacing: 10) {
                    if let onMarkPaid {
                        Button(BuxCatalogLabel.string("Paid", locale: appSettingsManager.interfaceLocale)) {
                            onMarkPaid(item.id)
                        }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                    if onRemind != nil {
                        Button(BuxCatalogLabel.string("Send", locale: appSettingsManager.interfaceLocale)) {
                            onRemind?(item)
                        }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
            }
        }
        .padding(.horizontal, BuxTokens.section)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(item.id) }
    }

    private func quoteStatusChip(for item: SimpleWaitingItem) -> String? {
        guard let entry = simpleStore.entry(id: item.id), entry.kind == .job else { return nil }
        if let agreed = entry.agreedPrice, agreed > 0 { return nil }
        return BuxCatalogLabel.string("No quote", locale: appSettingsManager.interfaceLocale)
    }

    private func chipColor(_ label: String) -> Color {
        _ = label
        return .orange
    }
}

// MARK: - I owe

struct SimpleStudioIOweSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let items: [SimpleWaitingItem]
    var onMarkSettled: ((UUID) -> Void)?
    var onTap: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "You owe")

            if items.isEmpty {
                EmptyView()
            } else {
                List {
                    ForEach(Array(items.prefix(5))) { item in
                        oweRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if let onMarkSettled {
                                    Button(BuxCatalogLabel.string("Settled", locale: appSettingsManager.interfaceLocale)) {
                                        onMarkSettled(item.id)
                                    }
                                        .tint(.green)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.visible)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(min(items.count, 5)) * 64)
                .background(themeManager.cardFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                        .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                )
            }
        }
    }

    private func oweRow(_ item: SimpleWaitingItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.customerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(
                    BuxLocalizedString.format(
                        "%@ · %lldd",
                        locale: appSettingsManager.interfaceLocale,
                        item.jobLabel,
                        item.daysWaiting
                    )
                )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(item.amountFormatted)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                if let onMarkSettled {
                    Button(BuxCatalogLabel.string("Settled", locale: appSettingsManager.interfaceLocale)) {
                        onMarkSettled(item.id)
                    }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, BuxTokens.section)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(item.id) }
    }
}

// MARK: - Recent

struct SimpleStudioRecentSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let items: [SimpleRecentItem]
    var onTap: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Recent")

            if items.isEmpty {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                    BuxCatalogDynamicText(key: "Tap + to scan or log your first job.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                }
            } else {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider().padding(.leading, 44) }
                            recentRow(item)
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ item: SimpleRecentItem) -> some View {
        HStack(spacing: 12) {
            recentLeadingThumb(item)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
            }
            Spacer(minLength: 0)
            Text(item.amountFormatted)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(item.isPositive ? .green : themeManager.labelPrimary(for: colorScheme))
        }
        .padding(.horizontal, BuxTokens.section)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onTap?(item.id) }
    }

    @ViewBuilder
    private func recentLeadingThumb(_ item: SimpleRecentItem) -> some View {
        if let image = SimpleStudioScanImageStore.load(path: item.photoPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                        .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                    .fill(item.isPositive ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: item.isPositive ? "arrow.down" : "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(item.isPositive ? .green : .orange)
            }
        }
    }
}

// MARK: - Tax tile

struct SimpleStudioTaxSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let tile: SimpleTaxTileDisplay
    var onOpenFullTax: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Your numbers")

            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: BuxTokens.tight
                    ) {
                        taxCell("You made", tile.made)
                        taxCell("You spent", tile.spent)
                        taxCell("You keep", tile.keep)
                        taxCell("Might owe", tile.mightOwe)
                    }
                    Text(tile.coachLine)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)

                    if let onOpenFullTax {
                        Button(action: onOpenFullTax) {
                            HStack {
                                Label {
                                    BuxCatalogText.text("Full Tax Studio in Pro")
                                } icon: {
                                    Image(systemName: "sparkles")
                                }
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func taxCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(title)
                .font(.system(size: 10, weight: .semibold))
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SimpleStudioEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.block) {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                BuxCatalogDynamicText(key: "Track every job. Every payment.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                BuxCatalogDynamicText(key: "Scan a payment screenshot or log money with + — not a bank, your private ledger.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
