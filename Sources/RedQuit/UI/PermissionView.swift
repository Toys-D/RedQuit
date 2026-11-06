import SwiftUI

/// Окно «Нужен доступ к Универсальному доступу».
struct PermissionView: View {
    @ObservedObject var permissions: PermissionManager
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                Text(L10n.permissionHeading)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(L10n.permissionBody)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.permissionStep1)
                Text(L10n.permissionStep2)
                Text(L10n.permissionStep3)
            }
            .fixedSize(horizontal: false, vertical: true)

            Text(L10n.permissionAfterUpdate)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if permissions.isTrusted {
                    Label(L10n.permissionGranted, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L10n.permissionWaiting).foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)

            HStack {
                Spacer()
                Button(permissions.isTrusted ? L10n.permissionDone : L10n.permissionLater, action: onClose)
                if !permissions.isTrusted {
                    Button(L10n.permissionOpenSettings) { permissions.requestAccess() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
