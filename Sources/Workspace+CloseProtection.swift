import Bonsplit

extension Workspace {
    /// Intercepts only interactive remote last-surface closes that remove the workspace.
    /// Confirmed workspace closure detaches before a remote pane command can destroy it.
    func protectRemoteTmuxLastSurfaceClose(tabId: TabID, explicitUserClose: Bool,
                                          tabStripClose: Bool, tabCloseButton: Bool, forced: Bool) -> Bool {
        guard isRemoteTmuxMirror, !forced, explicitUserClose,
              shouldCloseWorkspaceOnLastSurface(for: tabId, tabStripClose: tabStripClose),
              let manager = owningTabManager, manager.requiresAlwaysConfirmWorkspaceClose else { return false }
        clearRemoteTmuxWorkspaceCloseIntent(tabId: tabId)
        clearCloseHistoryEligibility(tabId: tabId)
        if tabCloseButton { _ = manager.closeWorkspaceFromTabCloseButton(self) }
        else { _ = manager.closeWorkspaceFromCloseTabGesture(self) }
        return true
    }
}
