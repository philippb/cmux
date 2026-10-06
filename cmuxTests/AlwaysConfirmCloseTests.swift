import AppKit
import Bonsplit
import CmuxSettings
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@MainActor
@Suite(.serialized)
struct AlwaysConfirmCloseTests {
    enum WorkspaceCloseAction: CaseIterable {
        case workspace, gesture, button

        @MainActor func close(_ workspace: Workspace, using manager: TabManager) -> Bool {
            switch self {
            case .workspace: return manager.closeWorkspaceWithConfirmation(workspace)
            case .gesture: return manager.closeWorkspaceFromCloseTabGesture(workspace)
            case .button: return manager.closeWorkspaceFromTabCloseButton(workspace)
            }
        }
    }

    @Test(arguments: WorkspaceCloseAction.allCases)
    func idleWorkspaceCancellationProtectsEveryCloseAction(_ action: WorkspaceCloseAction) {
        withManager(alwaysWorkspace: true) { manager in
            let workspace = manager.tabs[1]
            let panelIds = Set(workspace.panels.keys)
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }

            #expect(!action.close(workspace, using: manager))
            #expect(prompts == 1)
            #expect(manager.tabs.contains(where: { $0.id == workspace.id }))
            #expect(Set(workspace.panels.keys) == panelIds)
        }
    }

    @Test(arguments: WorkspaceCloseAction.allCases)
    func acceptingIdleWorkspaceCloseAsksOnce(_ action: WorkspaceCloseAction) {
        withManager(alwaysWorkspace: true) { manager in
            let workspace = manager.tabs[1]
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return true }

            #expect(action.close(workspace, using: manager))
            #expect(prompts == 1)
            #expect(!manager.tabs.contains(where: { $0.id == workspace.id }))
        }
    }

    @Test func disabledPreferencesPreserveIdleWorkspaceClose() {
        withManager { manager in
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }
            #expect(manager.closeWorkspaceWithConfirmation(manager.tabs[1]))
            #expect(prompts == 0)
        }
    }

    @Test func windowPreferenceDoesNotProtectNonLastWorkspace() {
        withManager(alwaysWindow: true) { manager in
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }
            #expect(manager.closeWorkspaceWithConfirmation(manager.tabs[1]))
            #expect(prompts == 0)
        }
    }

    @Test func protectionCannotOfferDontAskAgain() {
        withManager(alwaysWorkspace: true) { manager in
            var offered = false
            manager.confirmCloseHandler = { _, _, _ in false }
            manager.confirmCloseDontAskAgainHandler = { _ in offered = true; return true }
            #expect(!manager.closeWorkspaceWithConfirmation(manager.tabs[1]))
            #expect(!offered)
            #expect(manager.closeTabWarningDefaults.bool(forKey: "alwaysConfirmWorkspaceClose"))
        }
    }

    @Test func pinnedProtectionStillUsesOnePinnedPrompt() {
        withManager(alwaysWorkspace: true) { manager in
            let workspace = manager.tabs[1]
            manager.setPinned(workspace, pinned: true)
            var titles: [String] = []
            manager.confirmCloseHandler = { title, _, _ in titles.append(title); return true }
            #expect(manager.closeWorkspaceWithConfirmation(workspace))
            #expect(titles == [String(localized: "dialog.closePinnedWorkspace.title", defaultValue: "Close pinned workspace?")])
        }
    }

    @Test func cancelledBatchPreservesAllTargets() {
        withManager(alwaysWorkspace: true) { manager in
            let original = manager.tabs.map(\.id)
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }
            manager.closeWorkspacesWithConfirmation(Array(original.prefix(2)), allowPinned: true)
            #expect(prompts == 1)
            #expect(manager.tabs.map(\.id) == original)
        }
    }

    @Test func acceptedBatchAsksOnce() {
        withManager(alwaysWorkspace: true) { manager in
            let survivor = manager.tabs[2].id
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return true }
            manager.closeWorkspacesWithConfirmation(Array(manager.tabs.prefix(2).map(\.id)), allowPinned: true)
            #expect(prompts == 1)
            #expect(manager.tabs.map(\.id) == [survivor])
        }
    }

    @Test(arguments: [true, false])
    func batchClosingWindowHonorsEitherPreference(_ workspacePreference: Bool) {
        withManager(alwaysWorkspace: workspacePreference, alwaysWindow: !workspacePreference) { manager in
            let original = manager.tabs.map(\.id)
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }
            manager.closeWorkspacesWithConfirmation(original, allowPinned: true)
            #expect(prompts == 1)
            #expect(manager.tabs.map(\.id) == original)
        }
    }

    @Test func noninteractiveCloseDoesNotPrompt() {
        withManager(alwaysWorkspace: true, alwaysWindow: true) { manager in
            let workspace = manager.tabs[1]
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }
            #expect(manager.closeWorkspaceNonInteractively(workspace))
            #expect(prompts == 0)
            #expect(!manager.tabs.contains(where: { $0.id == workspace.id }))
        }
    }

    @Test(arguments: [true, false], [true, false])
    func lastSurfaceCloseHonorsWorkspaceProtection(_ button: Bool, _ remoteMirror: Bool) throws {
        try withManager(alwaysWorkspace: true) { manager in
            let workspace = manager.tabs[1]
            workspace.isRemoteTmuxMirror = remoteMirror
            let panelId = try #require(workspace.focusedPanelId)
            let surfaceId = try #require(workspace.surfaceIdFromPanelId(panelId))
            let pane = try #require(workspace.bonsplitController.allPaneIds.first)
            let tab = try #require(workspace.bonsplitController.tab(surfaceId))
            if button { workspace.markTabCloseButtonClose(surfaceId: surfaceId) }
            else { workspace.markExplicitClose(surfaceId: surfaceId) }
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }

            #expect(!workspace.splitTabBar(workspace.bonsplitController, shouldCloseTab: tab, inPane: pane))
            #expect(prompts == 1)
            #expect(manager.tabs.contains(where: { $0.id == workspace.id }))
            #expect(workspace.panels[panelId] != nil)
        }
    }

    @Test func preferencesRemainIndependentForWindowPolicy() {
        withManager(alwaysWorkspace: true) { manager in
            #expect(!manager.shouldConfirmWindowClose(windowDockNeedsConfirmation: false))
        }
        withManager(alwaysWindow: true) { manager in
            #expect(manager.shouldConfirmWindowClose(windowDockNeedsConfirmation: false))
        }
    }

    private func withManager(
        alwaysWorkspace: Bool = false,
        alwaysWindow: Bool = false,
        body: (TabManager) throws -> Void
    ) rethrows {
        let suite = "AlwaysConfirmCloseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(alwaysWorkspace, forKey: "alwaysConfirmWorkspaceClose")
        defaults.set(alwaysWindow, forKey: "alwaysConfirmWindowClose")
        defaults.set(false, forKey: "warnBeforeClosingWorkspace")
        defaults.set(false, forKey: "warnBeforeClosingWindow")
        defaults.set(false, forKey: "warnBeforeClosingTabShortcut")
        defaults.set(false, forKey: "warnBeforeClosingTabXButton")
        defaults.set(true, forKey: "closeWorkspaceOnLastSurfaceShortcut")
        let manager = TabManager(autoWelcomeIfNeeded: false,
                                 settings: UserDefaultsSettingsClient(defaults: defaults),
                                 closeTabWarningDefaults: defaults)
        while manager.tabs.count < 3 { _ = manager.addWorkspace(autoWelcomeIfNeeded: false) }
        for workspace in manager.tabs {
            for panelId in workspace.panels.keys {
                workspace.updatePanelShellActivityState(panelId: panelId, state: .promptIdle)
            }
        }
        defer { manager.closeWorkspacesForTesting() }
        try body(manager)
    }
}

@MainActor
@Suite(.serialized)
struct AlwaysConfirmWindowCloseTests {
    @Test func automaticShellExitKeepsExistingWindowClosePolicy() throws {
        try withWindow(alwaysWindow: true) { app, window, manager in
            let workspace = try #require(manager.selectedWorkspace)
            var prompts = 0
            var cancellations = 0
            app.debugCloseMainWindowConfirmationHandler = { _ in prompts += 1; return true }

            app.closeMainWindowContainingTabId(workspace.id, recordHistory: false,
                                              onCancelled: { cancellations += 1 })

            #expect(prompts == 0)
            #expect(cancellations == 0)
            #expect(!window.isVisible)
        }
    }

    @Test(arguments: [true, false])
    func cancelledWindowClosePreservesIdleWindow(_ titlebar: Bool) throws {
        try withWindow(alwaysWindow: true) { app, window, manager in
            var prompts = 0
            var suppressionOffered = false
            app.debugCloseMainWindowConfirmationHandler = { _ in prompts += 1; return false }
            app.debugCloseMainWindowDontAskAgainHandler = { _ in suppressionOffered = true; return true }
            let workspaceIds = manager.tabs.map(\.id)

            if titlebar { window.performClose(nil) }
            else { _ = app.closeWindowWithConfirmation(window) }

            #expect(prompts == 1)
            #expect(!suppressionOffered)
            #expect(window.isVisible)
            #expect(manager.tabs.map(\.id) == workspaceIds)
            #expect(manager.closeTabWarningDefaults.bool(forKey: "alwaysConfirmWindowClose"))
        }
    }

    @Test(arguments: [true, false])
    func acceptedWindowCloseCarriesConfirmation(_ titlebar: Bool) throws {
        try withWindow(alwaysWindow: true) { app, window, _ in
            var prompts = 0
            var confirmations: [Bool] = []
            app.debugCloseMainWindowConfirmationHandler = { _ in prompts += 1; return true }
            app.mainWindowShouldCloseObserverForTesting = { _, confirmed in confirmations.append(confirmed) }

            if titlebar { window.performClose(nil) }
            else { _ = app.closeWindowWithConfirmation(window) }

            #expect(prompts == 1)
            #expect(confirmations == [true])
        }
    }

    @Test func closingLastWorkspaceUsesOnePromptWithBothPreferencesEnabled() throws {
        try withWindow(alwaysWorkspace: true, alwaysWindow: true) { app, window, manager in
            let workspace = try #require(manager.selectedWorkspace)
            var workspacePrompts = 0
            var windowPrompts = 0
            var confirmations: [Bool] = []
            manager.confirmCloseHandler = { _, _, _ in workspacePrompts += 1; return true }
            app.debugCloseMainWindowConfirmationHandler = { _ in windowPrompts += 1; return true }
            app.mainWindowShouldCloseObserverForTesting = { target, confirmed in
                if target === window { confirmations.append(confirmed) }
            }

            #expect(manager.closeWorkspaceWithConfirmation(workspace))
            #expect(workspacePrompts == 1)
            #expect(windowPrompts == 0)
            #expect(confirmations == [true])
        }
    }

    @Test func windowPreferenceProtectsLastWorkspaceEvenWithWorkspacePreferenceOff() throws {
        try withWindow(alwaysWindow: true) { _, window, manager in
            let workspace = try #require(manager.selectedWorkspace)
            var prompts = 0
            manager.confirmCloseHandler = { _, _, _ in prompts += 1; return false }

            #expect(!manager.closeWorkspaceWithConfirmation(workspace))
            #expect(prompts == 1)
            #expect(window.isVisible)
            #expect(manager.tabs.map(\.id) == [workspace.id])
        }
    }

    private func withWindow(
        alwaysWorkspace: Bool = false,
        alwaysWindow: Bool = false,
        body: (AppDelegate, NSWindow, TabManager) throws -> Void
    ) throws {
        let app = try #require(AppDelegate.shared)
        let defaults = UserDefaults.standard
        let values = ["alwaysConfirmWorkspaceClose": alwaysWorkspace,
                      "alwaysConfirmWindowClose": alwaysWindow,
                      "warnBeforeClosingWorkspace": false,
                      "warnBeforeClosingWindow": false]
        let originals = values.keys.map { ($0, defaults.object(forKey: $0)) }
        for (key, value) in values { defaults.set(value, forKey: key) }
        defer {
            app.debugCloseMainWindowConfirmationHandler = nil
            app.debugCloseMainWindowDontAskAgainHandler = nil
            app.mainWindowShouldCloseObserverForTesting = nil
            for (key, original) in originals {
                if let original { defaults.set(original, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        let windowId = app.createMainWindow()
        let window = try #require(NSApp.windows.first { $0.identifier?.rawValue == "cmux.main.\(windowId.uuidString)" })
        let manager = try #require(app.tabManagerFor(windowId: windowId))
        window.makeKeyAndOrderFront(nil)
        for workspace in manager.tabs {
            for panelId in workspace.panels.keys {
                workspace.updatePanelShellActivityState(panelId: panelId, state: .promptIdle)
            }
        }
        defer {
            app.mainWindowShouldCloseObserverForTesting = nil
            manager.closeWorkspacesForTesting()
            app.suppressClosedWindowHistoryForTesting(windowId: windowId)
            window.close()
            app.forgetRecoverableMainWindowRoute(windowId: windowId)
        }
        try body(app, window, manager)
    }
}
