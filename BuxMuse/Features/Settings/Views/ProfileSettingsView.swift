//
//  ProfileSettingsView.swift
//  BuxMuse
//
//  Premium Profile customization view with local avatar support.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var preferredNameStyle: PreferredNameStyle = .fullName
    @State private var selectedAvatarData: Data? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var showCropSheet = false
    @State private var showNativePicker = false
    @State private var loadFailed = false
    @State private var photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Avatar & identity") {
                HStack(spacing: BuxLayout.section) {
                    Button(action: { showNativePicker = true }) {
                        avatarPreview
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogDynamicText(key: "Profile photo")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Saved locally on your device.")
                            .font(.system(size: 12))
                            .buxLabelSecondary()
                        if loadFailed {
                            BuxCatalogDynamicText(key: "Couldn't load that photo — try another image.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Name settings") {
                TextField("Name(s)", text: $firstName)
                    .font(.system(size: 15, weight: .medium))
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                TextField("Surname(s)", text: $lastName)
                    .font(.system(size: 15, weight: .medium))
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Display Style", selection: $preferredNameStyle) {
                    ForEach(PreferredNameStyle.allCases) { style in
                        Text(style.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Photo access settings") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Photo library access")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Select how many photos BuxMuse can access in system settings.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .buxFormFieldPadding()

                BuxFormRowDivider()

                Button {
                    BusinessCardPhotoLibraryAccess.openSettings()
                } label: {
                    HStack {
                        Image(systemName: photoStatus == .limited ? "photo.badge.checkmark" : "photo.on.rectangle.angled")
                            .foregroundColor(themeManager.current.accentColor)
                        Text(
                            BuxLocalizedString.format(
                                "Photos: %@",
                                locale: BuxInterfaceLocale.currentInterfaceLocale,
                                photoStatus.label
                            )
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        BuxCatalogDynamicText(key: "Manage photo access")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.current.accentColor)
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormSection {
                Button.buxDestructive("Reset to Defaults") {
                    firstName = ""
                    lastName = ""
                    selectedAvatarData = nil
                    preferredNameStyle = .fullName
                    saveProfile()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firstName = store.firstName ?? ""
            lastName = store.lastName ?? ""
            preferredNameStyle = store.preferredNameStyle
            selectedAvatarData = store.profileAvatarData
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
        }
        .onChange(of: firstName) { _, _ in saveProfile() }
        .onChange(of: lastName) { _, _ in saveProfile() }
        .onChange(of: preferredNameStyle) { _, _ in saveProfile() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            photoStatus = BusinessCardPhotoLibraryAccess.currentStatus()
        }
        .onChange(of: showNativePicker) { _, show in
            guard show else { return }
            GlobalImagePickerCoordinator.shared.present { image in
                if let image {
                    loadFailed = false
                    pickedImage = image
                    showCropSheet = true
                } else {
                    loadFailed = true
                }
                showNativePicker = false
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let pickedImage {
                ImageCropView(
                    inputImage: pickedImage,
                    cropShape: .circle,
                    title: "Crop Avatar",
                    hint: "Drag to pan, slide to scale your avatar."
                ) { croppedImage in
                    if let croppedData = croppedImage.jpegData(compressionQuality: 0.8) {
                        selectedAvatarData = croppedData
                        saveProfile()
                    }
                }
                .environmentObject(themeManager)
                .buxThemedSheetContent()
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let data = selectedAvatarData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(themeManager.current.accentColor, lineWidth: 2))
        } else {
            ZStack {
                Circle()
                    .fill(themeManager.current.accentColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.current.accentColor)
            }
        }
    }

    private func saveProfile() {
        store.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstName
        store.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : lastName
        store.preferredNameStyle = preferredNameStyle
        store.profileAvatarData = selectedAvatarData
        store.save()
    }
}
