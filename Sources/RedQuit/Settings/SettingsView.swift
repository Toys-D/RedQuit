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
    /// Страница проекта (открывается кнопкой «Сайт»).
    static let website = URL(string: "https://github.com/Toys-D/RedQuit")!

    @ObservedObject var prefs: Preferences
    @ObservedObject var permissions: PermissionManager

    @State private var loginStatus = LoginItem.status
    @State private var loginError: String?
    @State private var addMessage: String?
    @State private var showBuiltIn = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section(L10n.sectionGeneral) {
                Toggle(L10n.settingsEnabled, isOn: $prefs.isEnabled)
                Picker(L10n.settingsMode, selection: $prefs.mode) {
                    ForEach(QuitMode.allCases) { mode in
                        Text(L10n.modeTitle(mode)).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(L10n.modeExplanation(prefs.mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.sectionStartup) {
                Toggle(L10n.settingsOpenAtLogin, isOn: loginBinding)
                if loginStatus == .requiresApproval {
                    HStack {
                        Text(L10n.settingsLoginNeedsApproval)
                            .font(.caption)
                        Spacer()
                        Button(L10n.settingsOpen) { LoginItem.openSystemSettings() }
                    }
                }
                if !LoginItem.isInApplicationsFolder {
                    Text(L10n.settingsNotInApplications)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section(L10n.sectionAccess) {
                if permissions.isTrusted {
                    Label(L10n.settingsAccessGranted, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Label(L10n.settingsAccessMissing, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(L10n.menuGrantAccess) { permissions.requestAccess() }
                    }
                }
            }

            Section {
                if prefs.userExclusions.isEmpty {
                    Text(L10n.exclusionsEmpty).foregroundStyle(.secondary)
                }
                ForEach(prefs.userExclusions, id: \.self) { bundleID in
                    exclusionRow(ExclusionRow.make(bundleID: bundleID))
                }
                HStack {
                    Button(L10n.exclusionsAdd, action: addApplications)
                    if let addMessage {
                        Text(addMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DisclosureGroup(L10n.exclusionsBuiltIn(ExclusionRules.builtIn.count + 1), isExpanded: $showBuiltIn) {
                    exclusionRow(ExclusionRow.make(bundleID: Bundle.main.bundleIdentifier ?? "RedQuit",
                                                   builtInName: L10n.exclusionsThisApp))
                    ForEach(ExclusionRules.builtIn) { item in
                        exclusionRow(ExclusionRow.make(bundleID: item.bundleID, builtInName: L10n.builtInName(item)))
                    }
                }
            } header: {
                Text(L10n.sectionExclusions)
            } footer: {
                Text(L10n.exclusionsFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section(L10n.sectionLog) {
                Text(L10n.logHint(Log.subsystem))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section(L10n.sectionAbout) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RedQuit").font(.headline)
                        Text(L10n.aboutVersion(version)).font(.caption).foregroundStyle(.secondary)
                        Text("© 2026 Pixmap Labs").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.aboutWebsite) { NSWorkspace.shared.open(Self.website) }
                }
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
                    .help(L10n.exclusionsBuiltInHelp)
            } else {
                Button {
                    prefs.removeExclusion(row.id)
                    addMessage = nil
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help(L10n.exclusionsRemoveHelp)
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
                    loginError = L10n.settingsLoginError(error.localizedDescription)
                    Log.app.error("Open at login error: \(error.localizedDescription, privacy: .public)")
                }
                loginStatus = LoginItem.status
            }
        )
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = L10n.exclusionsPanelTitle
        panel.prompt = L10n.exclusionsPanelPrompt
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }

        var added: [String] = []
        var skipped: [String] = []
        for url in panel.urls {
            var name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
                skipped.append(L10n.exclusionsNoBundleID(name))
                continue
            }
            if prefs.addExclusion(bundleID) {
                added.append(name)
            } else {
                skipped.append(L10n.exclusionsAlreadyListed(name))
            }
        }
        let separator = Locale.current.language.languageCode?.identifier == "ja" ? "、" : ", "
        var parts: [String] = []
        if !added.isEmpty { parts.append(L10n.exclusionsAdded(added.joined(separator: separator))) }
        if !skipped.isEmpty { parts.append(L10n.exclusionsSkipped(skipped.joined(separator: separator))) }
        addMessage = parts.joined(separator: " ")
    }
}
