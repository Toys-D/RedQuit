import SwiftUI

/// Окно «Нужен доступ к Универсальному доступу».
struct PermissionView: View {
    @ObservedObject var permissions: PermissionManager
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("RedQuit нужен доступ\nк Универсальному доступу")
                    .font(.title2.bold())
            }

            Text("Без него RedQuit не видит, что вы нажали именно красную кнопку закрытия, и не может проверить, какие окна остались у программы. RedQuit только читает сведения об окнах: он не нажимает ничего за вас и никогда не блокирует и не изменяет нажатия.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. Нажмите «Открыть Системные настройки».")
                Text("2. В разделе «Универсальный доступ» включите переключатель рядом с RedQuit.")
                Text("3. Всё — RedQuit заработает сам, перезапускать его не нужно.")
            }
            .fixedSize(horizontal: false, vertical: true)

            Group {
                if permissions.isTrusted {
                    Label("Доступ получен — RedQuit работает", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Ждём, пока вы включите доступ…").foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)

            HStack {
                Spacer()
                Button(permissions.isTrusted ? "Готово" : "Позже", action: onClose)
                if !permissions.isTrusted {
                    Button("Открыть Системные настройки") { permissions.requestAccess() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
