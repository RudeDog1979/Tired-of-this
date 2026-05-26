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
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
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
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text("Saved locally on your device.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
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
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await MainActor.run {
                        self.pickedImage = img
                        self.showCropSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let pickedImage {
                AvatarCropView(inputImage: pickedImage) { croppedImage in
                    if let croppedData = croppedImage.jpegData(compressionQuality: 0.8) {
                        self.selectedAvatarData = croppedData
                        saveProfile()
                    }
                }
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

// MARK: - Avatar Circular Image Cropper
struct AvatarCropView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    
    let inputImage: UIImage
    let onCrop: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 260
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Drag to pan, slide to scale your avatar.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 16)
                
                // Crop area container
                ZStack {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .frame(width: 320, height: 320)
                        .clipped()
                    
                    // Circular mask overlay
                    CircleCutoutOverlay(circleRadius: cropSize / 2)
                        .allowsHitTesting(false)
                }
                .frame(width: 320, height: 320)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // Scale Slider
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.gray)
                        Slider(value: $scale, in: 1.0...4.0)
                            .tint(themeManager.current.accentColor)
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    
                    Text("Scale: \(String(format: "%.1fx", scale))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Crop Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        if let cropped = performCrop() {
                            onCrop(cropped)
                        }
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
    }
    
    @MainActor
    private func performCrop() -> UIImage? {
        // Bake rotation and orientation metadata into the pixel buffer
        let normalized = inputImage.normalizedImage()
        
        let cropView = ZStack {
            Image(uiImage: normalized)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: 320, height: 320)
        }
        .frame(width: cropSize, height: cropSize)
        .clipped()
        
        let renderer = ImageRenderer(content: cropView)
        renderer.scale = 3.0 // High-resolution retina scale
        return renderer.uiImage
    }
}

// MARK: - UIImage Orientation Normalizer
extension UIImage {
    func normalizedImage() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

// Aspect fit helper extension
extension CGSize {
    func aspectFit(within container: CGSize) -> CGSize {
        let widthRatio = container.width / width
        let heightRatio = container.height / height
        let ratio = min(widthRatio, heightRatio)
        return CGSize(width: width * ratio, height: height * ratio)
    }
}

// Circle cutout mask in SwiftUI
struct CircleCutoutOverlay: View {
    let circleRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                
                path.addEllipse(in: CGRect(
                    x: size.width / 2 - circleRadius,
                    y: size.height / 2 - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
            
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: circleRadius * 2, height: circleRadius * 2)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }
}
