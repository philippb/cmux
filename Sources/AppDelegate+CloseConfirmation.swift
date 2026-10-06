import AppKit
import CmuxSettings

extension AppDelegate {
    /// Shell-exit recovery uses the existing quit policy, not interactive close preferences.
    /// Scope both the preflight and AppKit delegate callback to the exact window.
    func withAutomaticMainWindowClose(_ window: NSWindow?, _ body: () -> Void) {
        guard let window else { body(); return }
        let key = ObjectIdentifier(window)
        let inserted = automaticMainWindowCloses.insert(key).inserted
        defer { if inserted { automaticMainWindowCloses.remove(key) } }
        body()
    }

    func confirmCloseMainWindow(
        _ window: NSWindow,
        warningDefaults: UserDefaults,
        dontAskAgain: CloseWarningKinds
    ) -> Bool {
#if DEBUG
        if let debugCloseMainWindowConfirmationHandler {
            let accepted = debugCloseMainWindowConfirmationHandler(window)
            if !dontAskAgain.isEmpty, debugCloseMainWindowDontAskAgainHandler?(dontAskAgain) == true {
                CloseTabWarningStore(defaults: warningDefaults).disableWarnings(dontAskAgain)
            }
            return accepted
        }
#endif

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "dialog.closeWindow.title", defaultValue: "Close window?")
        alert.informativeText = String(
            localized: "dialog.closeWindow.message",
            defaultValue: "This will close the current window and all of its workspaces."
        )
        alert.addButton(withTitle: String(localized: "common.close", defaultValue: "Close"))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancel"))

        let alertWindow = alert.window
        if let closeButton = alert.buttons.first {
            alertWindow.defaultButtonCell = closeButton.cell as? NSButtonCell
            alertWindow.initialFirstResponder = closeButton
            DispatchQueue.main.async {
                _ = alertWindow.makeFirstResponder(closeButton)
            }
        }

        CloseDontAskAgainCheckbox.add(to: alert, offering: dontAskAgain)
        let accepted = alert.runModal() == .alertFirstButtonReturn
        CloseDontAskAgainCheckbox.apply(from: alert, offering: dontAskAgain, defaults: warningDefaults)
        return accepted
    }

    @discardableResult
    func closeWindowWithConfirmation(_ window: NSWindow) -> Bool {
        guard isMainTerminalWindow(window) else {
            window.performClose(nil)
            return true
        }
        // Explicit window protection also covers idle windows. An ordinary close
        // that skips the dialog leaves the last-window quit policy in charge.
        let shouldConfirm: Bool
        var dontAskAgain: CloseWarningKinds = .window
        let warningDefaults: UserDefaults
        if let context = mainWindowContext(forExactWindowIdentity: window) {
            warningDefaults = context.tabManager.closeTabWarningDefaults
            let windowDockNeedsConfirmation = context.existingWindowDock()?.needsConfirmClose() == true
            shouldConfirm = context.tabManager.shouldConfirmWindowClose(
                windowDockNeedsConfirmation: windowDockNeedsConfirmation
            )
            if windowDockNeedsConfirmation
                || context.tabManager.tabs.contains(where: {
                    context.tabManager.workspaceNeedsConfirmClose($0)
                }) {
                dontAskAgain.insert(.safety)
            }
        } else {
            warningDefaults = .standard
            shouldConfirm = AppCatalogSection().alwaysConfirmWindowClose.value(in: warningDefaults)
                || CloseTabWarningStore(defaults: warningDefaults).warnsBeforeClosingWindow
        }
        if AppCatalogSection().alwaysConfirmWindowClose.value(in: warningDefaults) { dontAskAgain = [] }
        guard shouldConfirm else {
            window.performClose(nil)
            return true
        }
        guard confirmCloseMainWindow(
            window,
            warningDefaults: warningDefaults,
            dontAskAgain: dontAskAgain
        ) else { return true }
        performPreconfirmedMainWindowClose(window)
        return true
    }

}
