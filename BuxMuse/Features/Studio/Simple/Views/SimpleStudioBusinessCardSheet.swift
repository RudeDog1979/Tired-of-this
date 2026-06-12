//
//  SimpleStudioBusinessCardSheet.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioBusinessCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var name = ""
    @State private var tagline = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var skills = ""
    @State private var photoPath: String?
    @State private var cardPhoto: UIImage?
    @State private var pickedImage: UIImage?
    @State private var showNativePicker = false
    @State private var showCropSheet = false
    @State private var photoLoadFailed = false
    @State private var didLoad = false
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?

    private var isProStudio: Bool { settingsStore.studioMode == .pro }

    private var brandLogo: UIImage? {
        guard isProStudio, let data = studioStore.profile.logoData else { return nil }
        return UIImage(data: data)
    }

    private var qrPayload: String {
        var parts: [String] = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(name)"]
        if !tagline.isEmpty { parts.append("ORG:\(tagline)") }
        if !phone.isEmpty { parts.append("TEL;TYPE=CELL:\(phone)") }
        if !email.isEmpty { parts.append("EMAIL:\(email)") }
        parts.append("END:VCARD")
        return parts.joined(separator: "\n")
    }

    private var qrImage: UIImage? {
        guard isProStudio else { return nil }
        return InvoiceDesignerEngine.generateQRImage(from: qrPayload, size: 120)
    }

    var body: some View {
        Group {
            if usesPadSplitLayout {
                businessCardLayer
            } else {
                NavigationStack {
                    businessCardLayer
                }
            }
        }
    }

    private var businessCardLayer: some View {
        ZStack {
            if !usesPadSplitLayout {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: BuxTokens.block) {
                    BuxThemedCardForm {
                            BuxFormSection(title: "Photo (optional)") {
                                HStack(spacing: BuxTokens.section) {
                                    Button {
                                        showNativePicker = true
                                    } label: {
                                        photoPreview
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: BuxTokens.tight) {
                                        Button {
                                            showNativePicker = true
                                        } label: {
                                            Label {
                                                Text(BuxCatalogLabel.string(cardPhoto == nil ? "Choose photo" : "Change photo", locale: appSettingsManager.interfaceLocale))
                                            } icon: {
                                                Image(systemName: "photo.on.rectangle")
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                        }
                                        if cardPhoto != nil {
                                            Button(role: .destructive) {
                                                cardPhoto = nil
                                                photoPath = nil
                                            } label: {
                                                Text(BuxCatalogLabel.string("Remove photo", locale: appSettingsManager.interfaceLocale))
                                            }
                                            .font(.system(size: 13, weight: .medium))
                                        }
                                        if photoLoadFailed {
                                            BuxCatalogDynamicText(key: "Couldn't load that photo — try another.")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .buxFormFieldPadding()
                            }

                            BuxFormSection(title: "Your card") {
                                TextField(BuxCatalogLabel.string("Name / business", locale: appSettingsManager.interfaceLocale), text: $name)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("What you do", locale: appSettingsManager.interfaceLocale), text: $tagline)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Phone / WhatsApp", locale: appSettingsManager.interfaceLocale), text: $phone)
                                    .keyboardType(.phonePad)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Email (optional)", locale: appSettingsManager.interfaceLocale), text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Skills & jobs I do", locale: appSettingsManager.interfaceLocale), text: $skills, axis: .vertical)
                                    .lineLimit(2...4)
                                    .buxFormFieldPadding()
                            }
                        }

                        if !isProStudio {
                            proHintBanner
                        }

                        if canPreview {
                            cardPreview
                                .padding(.horizontal, BuxTokens.marginRegular)
                        }

                        VStack(spacing: BuxTokens.tight) {
                            BuxButton(
                                title: "Save card",
                                systemImage: "square.and.arrow.down",
                                role: .primary,
                                expands: true,
                                isEnabled: canPreview
                            ) {
                                saveCard(showFeedback: true)
                            }

                            BuxButton(
                                title: "Send card",
                                systemImage: "paperplane.fill",
                                role: .secondary,
                                expands: true,
                                isEnabled: canPreview
                            ) {
                                sendCard()
                            }

                            if isProStudio {
                                BuxButton(
                                    title: "Export PDF",
                                    systemImage: "doc.richtext",
                                    role: .secondary,
                                    expands: true,
                                    isEnabled: canPreview
                                ) {
                                    exportPDF()
                                }
                            }
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .padding(.bottom, BuxTokens.sheetBottomClearance)
                    }
                    .padding(.top, BuxTokens.section)
                    .environment(\.studioEnhancedTint, true)
                }
            }
        .buxCatalogNavigationTitle("Business card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !usesPadSplitLayout {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
        }
        .buxRootNavigationChrome()
        .buxInterfaceLocale()
        .buxMeshSheetPresentation()
        .onAppear(perform: loadSavedCard)
        .onChange(of: showNativePicker) { _, show in
            guard show else { return }
            GlobalImagePickerCoordinator.shared.present { image in
                if let image {
                    photoLoadFailed = false
                    pickedImage = image
                    showCropSheet = true
                } else {
                    photoLoadFailed = true
                }
                showNativePicker = false
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let pickedImage {
                ImageCropView(
                    inputImage: pickedImage,
                    cropShape: .roundedRectangle(cornerRadius: 12),
                    title: BuxCatalogLabel.string("Crop photo", locale: appSettingsManager.interfaceLocale),
                    hint: BuxCatalogLabel.string("Drag to pan, slide to scale your card photo.", locale: appSettingsManager.interfaceLocale)
                ) { cropped in
                    cardPhoto = cropped
                    photoPath = SimpleStudioScanImageStore.saveBusinessCardPhoto(cropped)
                }
                .environmentObject(themeManager)
                .buxThemedSheetContent()
            }
        }
        .sheet(item: $proUpsellFeature) { feature in
            StudioProUpsellSheet(feature: feature)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
                .environmentObject(store)
        }
    }

    private var proHintBanner: some View {
        Button {
            proUpsellFeature = .businessCardPro
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogDynamicText(key: "Pro card extras")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogDynamicText(key: "QR code, logo, premium styling & PDF export")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(BuxTokens.section)
            .background(themeManager.accentWash(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, BuxTokens.marginRegular)
    }

    @ViewBuilder
    private var photoPreview: some View {
        Group {
            if let cardPhoto {
                Image(uiImage: cardPhoto)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 72, height: 72)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
        )
    }

    private var canPreview: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cardPreview: some View {
        SimpleBusinessCardView(
            name: name,
            tagline: tagline,
            phone: phone,
            email: email,
            skills: skills,
            photo: cardPhoto,
            accent: themeManager.contrastAccentColor(for: colorScheme),
            isProStyle: isProStudio,
            qrImage: qrImage,
            brandLogo: brandLogo
        )
    }

    private func loadSavedCard() {
        guard !didLoad else { return }
        didLoad = true

        if let saved = store.businessCard {
            name = saved.name
            tagline = saved.tagline
            phone = saved.phone
            email = saved.email
            skills = saved.skills
            photoPath = saved.photoPath
            cardPhoto = SimpleStudioScanImageStore.load(path: saved.photoPath)
            return
        }

        let profile = studioStore.profile
        if name.isEmpty {
            name = profile.businessName.isEmpty ? profile.displayName : profile.businessName
        }
        if tagline.isEmpty {
            tagline = profile.businessType.rawValue
        }
    }

    private func currentCardModel() -> SimpleBusinessCard {
        SimpleBusinessCard(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            skills: skills.trimmingCharacters(in: .whitespacesAndNewlines),
            photoPath: photoPath
        )
    }

    private func saveCard(showFeedback: Bool) {
        if let cardPhoto, photoPath == nil {
            photoPath = SimpleStudioScanImageStore.saveBusinessCardPhoto(cardPhoto)
        }
        store.saveBusinessCard(currentCardModel())
        if showFeedback {
            BuxSaveFeedback.success()
        }
    }

    private func renderedCardImage() -> UIImage? {
        SimpleStudioShareHelper.renderCard(
            SimpleBusinessCardView(
                name: name,
                tagline: tagline,
                phone: phone,
                email: email,
                skills: skills,
                photo: cardPhoto,
                accent: themeManager.contrastAccentColor(for: colorScheme),
                isProStyle: isProStudio,
                qrImage: qrImage,
                brandLogo: brandLogo
            )
            .environmentObject(appSettingsManager)
            .frame(width: 340)
            .fixedSize(horizontal: false, vertical: true)
        )
    }

    private func exportPDF() {
        saveCard(showFeedback: false)
        let cardView = SimpleBusinessCardView(
            name: name,
            tagline: tagline,
            phone: phone,
            email: email,
            skills: skills,
            photo: cardPhoto,
            accent: themeManager.contrastAccentColor(for: colorScheme),
            isProStyle: true,
            qrImage: qrImage,
            brandLogo: brandLogo
        )
        .environmentObject(appSettingsManager)
        guard let data = SimpleStudioBusinessCardPDFExporter.generatePDF(from: cardView),
              let url = SimpleStudioBusinessCardPDFExporter.temporaryFileURL(data: data) else { return }
        SimpleStudioShareHelper.present(items: [url])
    }

    private func sendCard() {
        saveCard(showFeedback: false)

        guard let cardImage = renderedCardImage() else {
            if let vcardURL = SimpleStudioVCardExporter.temporaryFileURL(for: currentCardModel(), photo: cardPhoto) {
                SimpleStudioShareHelper.present(items: [vcardURL, shareMessage])
            } else {
                SimpleStudioShareHelper.present(items: [shareMessage])
            }
            return
        }

        var items: [Any] = [cardImage]
        if let vcardURL = SimpleStudioVCardExporter.temporaryFileURL(for: currentCardModel(), photo: cardPhoto) {
            items.append(vcardURL)
        }
        items.append(shareMessage)
        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                sheetTitle: BuxCatalogLabel.string("Send card", locale: appSettingsManager.interfaceLocale),
                message: shareMessage,
                recipientPhone: phone.isEmpty ? nil : phone,
                shareItems: items
            ),
            openURL: openURL
        )
    }

    private var shareMessage: String {
        var lines = [name.trimmingCharacters(in: .whitespacesAndNewlines)]
        if !tagline.isEmpty { lines.append(tagline) }
        if !skills.isEmpty { lines.append(skills) }
        if !phone.isEmpty { lines.append(phone) }
        if !email.isEmpty { lines.append(email) }
        return lines.joined(separator: "\n")
    }
}

struct SimpleBusinessCardView: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let name: String
    let tagline: String
    let phone: String
    let email: String
    let skills: String
    var photo: UIImage?
    let accent: Color
    var isProStyle: Bool = false
    var qrImage: UIImage?
    var brandLogo: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 22, weight: .bold))
                    if !tagline.isEmpty {
                        Text(tagline)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isProStyle {
                    if let brandLogo {
                        Image(uiImage: brandLogo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accent)
                            .frame(width: 34, height: 34)
                            .background(accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            Divider()
            if !skills.isEmpty {
                labelRow(BuxCatalogLabel.string("Skills & jobs", locale: appSettingsManager.interfaceLocale), skills)
            }
            if !phone.isEmpty {
                labelRow(BuxCatalogLabel.string("Phone", locale: appSettingsManager.interfaceLocale), phone)
            }
            if !email.isEmpty {
                labelRow(BuxCatalogLabel.string("Email", locale: appSettingsManager.interfaceLocale), email)
            }

            HStack(alignment: .bottom) {
                Text(BuxCatalogLabel.string(isProStyle ? "Pro Studio · BuxMuse" : "Local · Private · BuxMuse", locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                if isProStyle, let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("Contact QR code")
                }
            }
        }
        .padding(22)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .fill(
                    isProStyle
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(uiColor: .secondarySystemGroupedBackground), accent.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .stroke(
                    isProStyle
                        ? LinearGradient(
                            colors: [accent.opacity(0.55), accent.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [accent.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isProStyle ? 1.5 : 1
                )
        )
    }

    private func labelRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
    }
}
