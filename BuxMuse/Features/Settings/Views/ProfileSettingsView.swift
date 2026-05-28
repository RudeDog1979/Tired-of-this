//
//  ProfileSettingsView.swift
//  BuxMuse
//
//  Premium Profile customization view with local avatar support.
//

import SwiftUI
import PhotosUI

struct ProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var displayName = ""
    @State private var preferredNameStyle: PreferredNameStyle = .fullName
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedAvatarData: Data? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var showCropSheet = false
    @State private var loadFailed = false

    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                Section("AVATAR & IDENTITY") {
                    HStack(spacing: BuxLayout.section) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile Photo")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text("Saved locally on your device.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            if loadFailed {
                                Text("Couldn't load that photo — try another image.")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("NAME SETTINGS") {
                    TextField("Display Name", text: $displayName)
                        .font(.system(size: 15, weight: .medium))

                    Picker("Display Style", selection: $preferredNameStyle) {
                        ForEach(PreferredNameStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Button(action: {
                        displayName = "Mitchell Santos"
                        selectedAvatarData = nil
                        preferredNameStyle = .fullName
                        saveProfile()
                    }) {
                        Text("Reset to Defaults")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = store.userDisplayName ?? ""
            preferredNameStyle = store.preferredNameStyle
            selectedAvatarData = store.profileAvatarData
        }
        .onChange(of: displayName) { _, _ in saveProfile() }
        .onChange(of: preferredNameStyle) { _, _ in saveProfile() }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                loadFailed = false
                if let img = await PhotoImageLoader.loadUIImage(from: item) {
                    await MainActor.run {
                        pickedImage = img
                        showCropSheet = true
                    }
                } else {
                    await MainActor.run { loadFailed = true }
                }
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
            }
        }
    }

    private func saveProfile() {
        store.userDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : displayName
        store.preferredNameStyle = preferredNameStyle
        store.profileAvatarData = selectedAvatarData
        store.save()
    }
}
