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

        func close(_ workspace: Workspace, using manager: TabManager) -> Bool {
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

    @Test(arguments: [true, false])
    func lastSurfaceCloseHonorsWorkspaceProtection(_ button: Bool) throws {
        try withManager(alwaysWorkspace: true) { manager in
            let workspace = manager.tabs[1]
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
