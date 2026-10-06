import CmuxSettings
import SwiftUI

/// Interactive workspace and window closure preferences in the App settings card.
struct AppCloseConfirmationSettingsRows: View {
    let catalog: SettingCatalog
    let warnWorkspace: DefaultsValueModel<Bool>
    let warnWindow: DefaultsValueModel<Bool>
    let alwaysConfirmWorkspaceClose: DefaultsValueModel<Bool>
    let alwaysConfirmWindowClose: DefaultsValueModel<Bool>

    var body: some View {
        // Warn Before Closing Workspace
        SettingsCardRow(
            configurationReview: .json(catalog.app.warnBeforeClosingWorkspace.id),
            catalog.app.warnBeforeClosingWorkspace.userFacing!.title,
            subtitle: alwaysConfirmWorkspaceClose.current
                ? String(localized: "settings.app.alwaysConfirmWorkspaceClose.subtitle", defaultValue: "Always ask before interactive workspace closures, even without running processes. Disable this protection in Settings.", bundle: .module)
                : warnWorkspace.current
                    ? String(localized: "settings.app.warnBeforeClosingWorkspace.subtitleOn", defaultValue: "Show a confirmation before closing a workspace with a running process, or several workspaces at once.")
                    : String(localized: "settings.app.warnBeforeClosingWorkspace.subtitleOff", defaultValue: "Workspaces close immediately without confirmation. Pinned workspaces still ask.")
        ) {
            Toggle("", isOn: Binding(get: { warnWorkspace.current }, set: { warnWorkspace.set($0) }))
                .labelsHidden()
                .controlSize(.small)
        }
        SettingsCardDivider()

        // Warn Before Closing Window
        SettingsCardRow(
            configurationReview: .json(catalog.app.warnBeforeClosingWindow.id),
            catalog.app.warnBeforeClosingWindow.userFacing!.title,
            subtitle: alwaysConfirmWindowClose.current
                ? String(localized: "settings.app.alwaysConfirmWindowClose.subtitle", defaultValue: "Always ask before interactive window closures, even without running processes. Quit confirmation is configured separately.", bundle: .module)
                : warnWindow.current
                    ? String(localized: "settings.app.warnBeforeClosingWindow.subtitleOn", defaultValue: "Show a confirmation before closing a window with a running process, or all of a window's workspaces at once.")
                    : String(localized: "settings.app.warnBeforeClosingWindow.subtitleOff", defaultValue: "Windows close immediately without confirmation.")
        ) {
            Toggle("", isOn: Binding(get: { warnWindow.current }, set: { warnWindow.set($0) }))
                .labelsHidden()
                .controlSize(.small)
        }
        SettingsCardDivider()

        SettingsCardRow(
            configurationReview: .json(catalog.app.alwaysConfirmWorkspaceClose.id),
            catalog.app.alwaysConfirmWorkspaceClose.userFacing!.title,
            subtitle: String(localized: "settings.app.alwaysConfirmWorkspaceClose.subtitle", defaultValue: "Always ask before interactive workspace closures, even without running processes. Disable this protection in Settings.", bundle: .module)
        ) {
            Toggle("", isOn: Binding(get: { alwaysConfirmWorkspaceClose.current }, set: { alwaysConfirmWorkspaceClose.set($0) }))
                .labelsHidden()
                .controlSize(.small)
        }
        SettingsCardDivider()

        SettingsCardRow(
            configurationReview: .json(catalog.app.alwaysConfirmWindowClose.id),
            catalog.app.alwaysConfirmWindowClose.userFacing!.title,
            subtitle: String(localized: "settings.app.alwaysConfirmWindowClose.subtitle", defaultValue: "Always ask before interactive window closures, even without running processes. Quit confirmation is configured separately.", bundle: .module)
        ) {
            Toggle("", isOn: Binding(get: { alwaysConfirmWindowClose.current }, set: { alwaysConfirmWindowClose.set($0) }))
                .labelsHidden()
                .controlSize(.small)
        }
        SettingsCardDivider()

    }
}
