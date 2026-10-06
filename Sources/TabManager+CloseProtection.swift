import CmuxSettings

extension TabManager {
    /// User-requested protection is independent of conditional warning toggles.
    var alwaysConfirmWorkspaceClose: Bool {
        AppCatalogSection().alwaysConfirmWorkspaceClose.value(in: closeTabWarningDefaults)
    }

    var alwaysConfirmWindowClose: Bool {
        AppCatalogSection().alwaysConfirmWindowClose.value(in: closeTabWarningDefaults)
    }

    /// A workspace close also closes its window when it is the last workspace.
    var requiresAlwaysConfirmWorkspaceClose: Bool {
        alwaysConfirmWorkspaceClose || (tabs.count <= 1 && alwaysConfirmWindowClose)
    }
}
