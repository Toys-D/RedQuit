import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import RedQuitCore

/// Строка списка исключений.
struct ExclusionRow: Identifiable {
    let id: String // bundle ID
    let name: String
    let icon: NSImage?
    let isBuiltIn: Bool

    @MainActor
    static func make(bundleID: String, builtInName: String? = nil) -> ExclusionRow {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            var name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            return ExclusionRow(id: bundleID, name: builtInName ?? name,
                                icon: workspace.icon(forFile: url.path), isBuiltIn: builtInName != nil)
        }
        return ExclusionRow(id: bundleID, name: builtInName ?? bundleID, icon: nil, isBuiltIn: builtInName != nil)
    }
}

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var permissions: PermissionManager

    @State private var loginStatus = LoginItem.status
    @State private var loginError: String?
    @State private var addMessage: String?
    @State private var showBuiltIn = false

    var body: some View {
        Form {
            Section("Работа") {
                Toggle("RedQuit включён", isOn: $prefs.isEnabled)
                Picker("Режим", selection: $prefs.mode) {
                    ForEach(QuitMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(prefs.mode.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Запуск") {
                Toggle("Запускать при входе в систему", isOn: loginBinding)
                if loginStatus == .requiresApproval {
                    HStack {
                        Text("macOS ждёт вашего подтверждения в «Объектах входа».")
                            .font(.caption)
                        Spacer()
                        Button("Открыть") { LoginItem.openSystemSettings() }
                    }
                }
                if !LoginItem.isInApplicationsFolder {
                    Text("RedQuit сейчас запущен не из папки «Программы». Для автозапуска сначала переместите его туда.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Доступ") {
                if permissions.isTrusted {
                    Label("Универсальный доступ разрешён", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Label("Нет доступа к Универсальному доступу", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Выдать доступ…") { permissions.requestAccess() }
                    }
                }
            }

            Section {
                if prefs.userExclusions.isEmpty {
                    Text("Список пуст").foregroundStyle(.secondary)
                }
                ForEach(prefs.userExclusions, id: \.self) { bundleID in
                    exclusionRow(ExclusionRow.make(bundleID: bundleID))
                }
                HStack {
                    Button("Добавить программу…", action: addApplications)
                    if let addMessage {
                        Text(addMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DisclosureGroup("Встроенные исключения (\(ExclusionRules.builtIn.count + 1))", isExpanded: $showBuiltIn) {
                    exclusionRow(ExclusionRow.make(bundleID: Bundle.main.bundleIdentifier ?? "RedQuit",
                                                   builtInName: "RedQuit (эта утилита)"))
                    ForEach(ExclusionRules.builtIn) { item in
                        exclusionRow(ExclusionRow.make(bundleID: item.bundleID, builtInName: item.name))
                    }
                }
            } header: {
                Text("Исключения")
            } footer: {
                Text("На эти программы RedQuit не действует. Фоновые программы без значка в Dock (агенты, утилиты строки меню) RedQuit не трогает никогда.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Журнал") {
                Text("Что RedQuit сделал и почему, видно в Console.app: в поиске введите «subsystem:\(Log.subsystem)».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 480, idealHeight: 640)
        .onAppear { loginStatus = LoginItem.status }
    }

    // MARK: - Строки

    @ViewBuilder
    private func exclusionRow(_ row: ExclusionRow) -> some View {
        HStack(spacing: 10) {
            if let icon = row.icon {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed").font(.system(size: 20)).frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                Text(row.id).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if row.isBuiltIn {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .help("Встроенное исключение — удалить нельзя")
            } else {
                Button {
                    prefs.removeExclusion(row.id)
                    addMessage = nil
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Удалить из исключений")
            }
        }
    }

    // MARK: - Действия

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { loginStatus == .enabled || loginStatus == .requiresApproval },
            set: { enabled in
                do {
                    try LoginItem.setEnabled(enabled)
                    loginError = nil
                } catch {
                    loginError = "Не удалось изменить автозапуск: \(error.localizedDescription)"
                    Log.app.error("Ошибка автозапуска: \(error.localizedDescription, privacy: .public)")
                }
                loginStatus = LoginItem.status
            }
        )
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "Выберите программы, на которые RedQuit не должен действовать"
        panel.prompt = "Добавить"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }

        var added: [String] = []
        var skipped: [String] = []
        for url in panel.urls {
            let name = FileManager.default.displayName(atPath: url.path)
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
                skipped.append("\(name) (нет bundle ID)")
                continue
            }
            if prefs.addExclusion(bundleID) {
                added.append(name)
            } else {
                skipped.append("\(name) (уже в списке)")
            }
        }
        var parts: [String] = []
        if !added.isEmpty { parts.append("Добавлено: \(added.joined(separator: ", "))") }
        if !skipped.isEmpty { parts.append("Пропущено: \(skipped.joined(separator: ", "))") }
        addMessage = parts.joined(separator: ". ")
    }
}
