import SwiftUI
import PhotosUI

struct PersonalInformationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showSaved = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    ProfileAvatarView(size: 104, ringColor: BuyWiseColors.surface)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Change photo", systemImage: "camera.fill")
                            .font(BuyWiseTypography.captionBold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(BuyWiseColors.brandSoft))
                            .foregroundStyle(BuyWiseColors.brand)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

                field(title: "Full name", text: $appState.userName)
                field(title: "Email", text: $appState.userEmail, keyboard: .emailAddress)

                PrimaryButton(title: showSaved ? "Saved" : "Save Changes", symbolName: showSaved ? "checkmark" : nil) {
                    showSaved = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        showSaved = false
                    }
                }
            }
            .padding(20)
        }
        .bwScreenBackground()
        .navigationTitle("Personal Information")
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    appState.setProfileImage(image.resizedForAvatar().jpegData(compressionQuality: 0.85))
                }
                photoItem = nil
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BuyWiseTypography.captionBold)
                .foregroundStyle(BuyWiseColors.textSecondary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .font(BuyWiseTypography.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                        .fill(BuyWiseColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BuyWiseTheme.controlRadius, style: .continuous)
                        .strokeBorder(BuyWiseColors.border, lineWidth: 1)
                )
        }
    }
}
